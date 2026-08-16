#!/usr/bin/env bash
# aiflow project-update - refresh THIS project's aiflow-generated files from the installed
# templates, then re-apply config.
#
# Refreshed (mechanical, always safe to overwrite): .aiflow/*.sh+ps1, .claude/hooks/*.sh+ps1,
# docker/run.sh+ps1, .github/scripts/* (aiflow's CI helpers - not meant to be edited).
# Refreshed (agent definitions + git hooks - see backup rule below): AGENTS.md, CLAUDE.md,
# .github/copilot-instructions.md, .claude/agents/*.md, .claude/commands/*.md,
# .claude/skills/*/SKILL.md, .githooks/*, .aiflow/router-config.example.json.
# Config: .aiflow/config.json keeps every value you set; keys a NEWER release introduced are
# filled in from templates/.aiflow/config.defaults.json, and meta.aiflowVersion is stamped.
# Backup rule: if a refreshed agent-definition file already differs from the incoming template
# (i.e. you customised it, or it's genuinely changed upstream), the OLD file is renamed to
# "<file>.bak" (never deleted) before the new one is written, and reported at the end so you can
# diff/reapply your customisations. Identical files are overwritten silently (nothing lost).
# Never deleted: project-update only copies. A helper aiflow drops or renames stays in the
# project; it is REPORTED at the end of the run (for .aiflow/ and .claude/hooks/, which are
# aiflow-owned) and left in place, because the same file may be one you added yourself.
# NEVER touched: .beads/ (issues), .claude/memory/* (project aim, conventions, codebase map, ...),
# .github/workflows/* (yours to extend - see below), and .aiflow/config.json's own content (only
# meta.aiflowVersion is stamped at the end) - your project aim, task history, and learned memory
# always survive a project-update.
#
# Why scripts but not workflows: the helpers aiflow ships into .github/scripts/ are mechanical and
# not meant to be edited, so they are simply overwritten. .github/workflows/ci.yml ships as a
# starting point that projects are expected to extend with their own jobs - overwriting it (or
# even backing it up and replacing it) would throw that away on every update. So a workflow step
# that needs a new helper is ADVISED at the very end of this run, never written. The one-way
# coupling is deliberate: the script is always present, so a project that adopts the step never
# hits a missing file; a project that ignores the advice just carries an unused script.
# Caveat: unlike .aiflow/ or .claude/hooks/, .github/scripts/ is a conventional shared directory,
# not an aiflow-owned namespace. A project file whose NAME collides with a shipped helper is
# overwritten without a .bak - so keep your own CI scripts under a name aiflow does not ship
# (today: check-frontmatter.py), or in a directory of your own.
set -uo pipefail

AIFLOW_HOME="${AIFLOW_HOME:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TPL="$AIFLOW_HOME/templates"
CFG=".aiflow/config.json"
[ -f "$CFG" ] || { echo "no $CFG - run 'aiflow init' first" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq required" >&2; exit 1; }

echo ">> aiflow project-update: refreshing mechanical scripts from templates..."
mkdir -p .aiflow .claude/hooks docker
shopt -s nullglob
for f in "$TPL"/.aiflow/*.sh "$TPL"/.aiflow/*.ps1; do cp -f "$f" ".aiflow/$(basename "$f")"; done
for f in "$TPL"/.claude/hooks/*.sh "$TPL"/.claude/hooks/*.ps1; do cp -f "$f" ".claude/hooks/$(basename "$f")"; done
for f in "$TPL"/docker/run.sh "$TPL"/docker/run.ps1; do cp -f "$f" "docker/$(basename "$f")"; done
shopt -u nullglob
# trailing /. so a subdirectory is merged into the destination, not nested one level deeper on
# every run (cp -rf dir dst/dir would give dst/dir/dir the second time round).
if [ -d "$TPL/.github/scripts" ]; then
  mkdir -p .github/scripts
  cp -rf "$TPL"/.github/scripts/. .github/scripts/
fi
chmod +x .aiflow/*.sh .claude/hooks/*.sh docker/*.sh 2>/dev/null || true
echo "   scripts refreshed"

# ---- agent definitions: back up before overwrite if the existing file was customised ----
echo ">> refreshing agent definitions + git hooks (customised files are kept as *.bak)..."
BACKED_UP=()
ADDED=()
refresh_with_backup() { # src dest
  local src="$1" dest="$2"
  [ -f "$src" ] || return 0
  mkdir -p "$(dirname "$dest")"
  if [ ! -f "$dest" ]; then
    cp -f "$src" "$dest"
    ADDED+=("$dest")
  elif ! cmp -s "$src" "$dest"; then
    mv -f "$dest" "$dest.bak"
    cp -f "$src" "$dest"
    BACKED_UP+=("$dest")
  fi
  # identical: nothing to do, no customisation lost
}

refresh_with_backup "$TPL/AGENTS.md" "AGENTS.md"
refresh_with_backup "$TPL/CLAUDE.md" "CLAUDE.md"
refresh_with_backup "$TPL/.github/copilot-instructions.md" ".github/copilot-instructions.md"

shopt -s nullglob
for f in "$TPL"/.claude/agents/*.md; do
  refresh_with_backup "$f" ".claude/agents/$(basename "$f")"
done
for f in "$TPL"/.claude/commands/*.md; do
  refresh_with_backup "$f" ".claude/commands/$(basename "$f")"
done
for f in "$TPL"/.claude/skills/*/SKILL.md; do
  name="$(basename "$(dirname "$f")")"
  refresh_with_backup "$f" ".claude/skills/$name/SKILL.md"
done
# The router example is a reference file a project copies to ~/.claude-code-router/config.json,
# so a stale one is worth refreshing — but it is also the obvious place to keep a tweaked sample,
# hence the .bak rule rather than the mechanical block above (aiflow-ver).
refresh_with_backup "$TPL/.aiflow/router-config.example.json" ".aiflow/router-config.example.json"

# Git hooks are enforcement policy a project tunes — but they are also how a shipped check
# reaches an existing project at all (aiflow-1l4's frontmatter guard reached only NEW projects
# while these were excluded). So they follow the .bak rule like the agent definitions, and the
# exec bit is re-applied below: a hook that lost it is silently skipped by git.
for f in "$TPL"/.githooks/*; do
  [ -f "$f" ] && refresh_with_backup "$f" ".githooks/$(basename "$f")"
done
shopt -u nullglob
chmod +x .githooks/* 2>/dev/null || true

# bash 3.2 (macOS system bash) treats an EMPTY array as unset under `set -u`, so
# "${ARR[@]}" / "${ARR[*]}" abort instead of expanding to nothing. The `+` form is the
# portable guard; the counts below only run where the array is known non-empty.
if [ -n "${ADDED[*]+x}" ]; then
  echo "   new: ${ADDED[*]}"
fi
if [ -n "${BACKED_UP[*]+x}" ]; then
  echo ""
  echo "   !! ${#BACKED_UP[@]} customised file(s) were REPLACED with the new template version."
  echo "      Your previous version was kept as *.bak — review the diff and reapply anything you"
  echo "      want to keep (it will NOT be merged automatically):"
  for f in "${BACKED_UP[@]}"; do echo "        $f  (backup: $f.bak)"; done
  echo ""
else
  echo "   agent definitions + git hooks were already up to date - nothing backed up."
fi

bash "$AIFLOW_HOME/lib/apply.sh"

# ---- config defaults: add keys a newer release introduced, never touch existing values ----
# Only `init`/`change-settings` write config.json, so a key added by a release never reached an
# already-generated project (aiflow-vxy). `defaults * config` merges recursively with the RIGHT
# side winning, so this can only add what the project does not set.
DEFAULTS="$TPL/.aiflow/config.defaults.json"
if [ -f "$DEFAULTS" ]; then
  TMPD="$(mktemp)"
  # `defaults * config` would work but reorders: the defaults' keys jump to the front, so every
  # project gets a needlessly large diff. This walks the defaults instead and only INSERTS what is
  # missing, leaving the project's own key order alone - which is what the .ps1 twin already did.
  if jq --slurpfile d "$DEFAULTS" '
       def addmissing($x):
         reduce ($x | to_entries[]) as $e (.;
           if has($e.key)
           then (if (.[$e.key] | type) == "object" and ($e.value | type) == "object"
                 then .[$e.key] |= addmissing($e.value) else . end)
           else .[$e.key] = $e.value end);
       addmissing($d[0] | del(.["$comment"]))' "$CFG" > "$TMPD" 2>/dev/null && [ -s "$TMPD" ]; then
    if cmp -s "$TMPD" "$CFG"; then
      rm -f "$TMPD"
    else
      mv "$TMPD" "$CFG"
      echo "   config.json: filled in defaults for keys this project did not have yet"
    fi
  else
    rm -f "$TMPD"
    echo "   ! could not merge config defaults - .aiflow/config.json left untouched" >&2
  fi
fi

NEW_VER="$(cat "$AIFLOW_HOME/VERSION" 2>/dev/null || echo 0.0.0)"
TMP="$(mktemp)"
jq --arg v "$NEW_VER" '.meta.aiflowVersion = $v' "$CFG" > "$TMP" && mv "$TMP" "$CFG"
echo ">> project-update done. Stamped .aiflow/config.json meta.aiflowVersion=$NEW_VER"
echo "   Untouched, as always: .beads/ (issues), .claude/memory/* (project aim, conventions, codebase map)."

# ---- CI advice: helpers WE ship that no workflow of yours references (never rewrite a workflow) ----
# Iterates the TEMPLATE's helpers, not the project's: only aiflow-shipped scripts have a matching
# step to point at. grep -F so a filename is matched literally, not as a regex.
if [ -d .github/workflows ]; then
  WF_MISSING=()
  shopt -s nullglob
  for f in "$TPL"/.github/scripts/*; do
    base="$(basename "$f")"
    grep -rqsF -- "$base" .github/workflows/ || WF_MISSING+=("$base")
  done
  shopt -u nullglob
  if [ -n "${WF_MISSING[*]+x}" ]; then
    echo ""
    echo "   note: .github/workflows/ is yours - project-update never rewrites it. These aiflow CI"
    echo "   helpers are now present, but no workflow under .github/workflows/ references them:"
    for b in "${WF_MISSING[@]}"; do echo "        .github/scripts/$b"; done
    echo "   Copy the matching step from $TPL/.github/workflows/ci.yml to enforce it."
  fi
fi

# ---- orphan advice: scripts in YOUR aiflow-owned directories that the templates no longer ship ----
# project-update copies, it never deletes - so a helper aiflow renamed or dropped would sit in the
# project forever, unmentioned (aiflow-400). Reported, never touched: the file may equally well be
# one you added. .github/scripts/ is deliberately NOT scanned - it is a conventional shared
# directory, so a project's own CI script there is normal and flagging it would be pure noise.
ORPHANS=()
shopt -s nullglob
for d in .aiflow .claude/hooks; do
  [ -d "$d" ] || continue
  for f in "$d"/*.sh "$d"/*.ps1; do
    [ -f "$TPL/$d/$(basename "$f")" ] || ORPHANS+=("$f")
  done
done
shopt -u nullglob
if [ -n "${ORPHANS[*]+x}" ]; then
  echo ""
  echo "   note: these are in your project but aiflow no longer ships them - a helper removed"
  echo "   upstream, or one of your own. Nothing was deleted; remove them yourself if unused:"
  for f in "${ORPHANS[@]}"; do echo "        $f"; done
fi
