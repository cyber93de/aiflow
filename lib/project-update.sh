#!/usr/bin/env bash
# aiflow project-update - refresh THIS project's aiflow-generated files from the installed
# templates, then re-apply config.
#
# Refreshed (mechanical, always safe to overwrite): .aiflow/*.sh+ps1, .claude/hooks/*.sh+ps1,
# docker/run.sh+ps1.
# Refreshed (agent definitions - see backup rule below): AGENTS.md, CLAUDE.md,
# .github/copilot-instructions.md, .claude/agents/*.md, .claude/commands/*.md,
# .claude/skills/*/SKILL.md.
# Backup rule: if a refreshed agent-definition file already differs from the incoming template
# (i.e. you customised it, or it's genuinely changed upstream), the OLD file is renamed to
# "<file>.bak" (never deleted) before the new one is written, and reported at the end so you can
# diff/reapply your customisations. Identical files are overwritten silently (nothing lost).
# NEVER touched: .beads/ (issues), .claude/memory/* (project aim, conventions, codebase map, ...),
# and .aiflow/config.json's own content (only meta.aiflowVersion is stamped at the end) - your
# project aim, task history, and learned memory always survive a project-update.
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
chmod +x .aiflow/*.sh .claude/hooks/*.sh docker/*.sh 2>/dev/null || true
echo "   scripts refreshed"

# ---- agent definitions: back up before overwrite if the existing file was customised ----
echo ">> refreshing agent definitions (customised files are kept as *.bak)..."
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
shopt -u nullglob

if [ "${#ADDED[@]}" -gt 0 ]; then
  echo "   new: ${ADDED[*]}"
fi
if [ "${#BACKED_UP[@]}" -gt 0 ]; then
  echo ""
  echo "   !! ${#BACKED_UP[@]} customised file(s) were REPLACED with the new template version."
  echo "      Your previous version was kept as *.bak — review the diff and reapply anything you"
  echo "      want to keep (it will NOT be merged automatically):"
  for f in "${BACKED_UP[@]}"; do echo "        $f  (backup: $f.bak)"; done
  echo ""
else
  echo "   agent definitions were already up to date - nothing backed up."
fi

bash "$AIFLOW_HOME/lib/apply.sh"

NEW_VER="$(cat "$AIFLOW_HOME/VERSION" 2>/dev/null || echo 0.0.0)"
TMP="$(mktemp)"
jq --arg v "$NEW_VER" '.meta.aiflowVersion = $v' "$CFG" > "$TMP" && mv "$TMP" "$CFG"
echo ">> project-update done. Stamped .aiflow/config.json meta.aiflowVersion=$NEW_VER"
echo "   Untouched, as always: .beads/ (issues), .claude/memory/* (project aim, conventions, codebase map)."
