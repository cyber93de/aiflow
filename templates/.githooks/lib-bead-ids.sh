#!/usr/bin/env bash
# Shared helper for the git hooks: warn about bead ids that do not exist.
#
# Invented ids are easy to write and hard to notice — they look right, and CI cannot check them
# (no `bd` in the runner, and the issue DB is not a tracked file). Locally `bd` is right there.
#
# WARNS, never blocks: an id can also be missing simply because a teammate's bead has not been
# pulled yet, and a commit is the wrong place to lose that argument. Silently skipped when `bd`
# or `jq` is absent, or outside a beads project.
#
# Usage: . "$(dirname "$0")/lib-bead-ids.sh"; printf '%s' "$text" | warn_unknown_bead_ids "<where>"

# The prefix is read from the issue DB, never hardcoded: a project that renamed its prefix
# (`bd rename-prefix`) must keep working without touching this file.
bead_prefix() {
  bd list --limit 1 --json 2>/dev/null | jq -r '(.[0].id // "") | sub("-[^-]+$"; "")' 2>/dev/null
}

warn_unknown_bead_ids() { # <context label>; text on stdin
  local where="${1:-input}" prefix ids missing
  command -v bd >/dev/null 2>&1 || return 0
  command -v jq >/dev/null 2>&1 || return 0
  [ -d .beads ] || return 0

  prefix="$(bead_prefix)"
  [ -n "$prefix" ] || return 0

  # `<prefix>-abc` or `<prefix>-abc.1` (bd's sub-task form)
  ids="$(grep -oE "${prefix}-[a-z0-9]{3}(\.[0-9]+)?" | sort -u)"
  [ -n "$ids" ] || return 0

  # One lookup for all of them. `bd show` exits 0 even for an unknown id, so the answer is read
  # from the JSON: on success an array of issues, on failure an object with .error.
  missing="$(bd show $ids --json 2>/dev/null \
    | jq -r --arg want "$ids" '
        (if type == "array" then [.[].id] else [] end) as $found
        | ($want | split("\n")) - $found | .[]' 2>/dev/null)"
  [ -n "$missing" ] || return 0

  echo "  ! $where references bead id(s) that do not exist here:" >&2
  for m in $missing; do echo "      $m" >&2; done
  echo "    (typo, or a teammate's bead you have not pulled — 'aiflow sync' to check)" >&2
  return 0
}
