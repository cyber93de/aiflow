#!/usr/bin/env bash
# Guard for this repo only (aiflow self-hosts its own agent roster): .claude/{agents,commands,
# skills} must mirror templates/.claude/*. Drift means we ship a roster we don't run ourselves,
# which is how ponytail/memory-setup went missing here for a whole release (aiflow-rsf).
#
# The generated `model:` frontmatter line is ignored - apply.sh stamps it into .claude/agents/*
# per modelRouting tier, and the templates deliberately carry no such line.
#
# Usage: bash .aiflow/roster-drift.sh [--fix]
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

FIX=0; [ "${1:-}" = "--fix" ] && FIX=1
fail=0

strip_generated() { grep -v '^model:[[:space:]]' "$1" | sed 's/\r$//'; }

for d in agents commands skills; do
  src="templates/.claude/$d"; dst=".claude/$d"
  [ -d "$src" ] || continue
  mkdir -p "$dst"

  # missing / extra entries
  while IFS= read -r name; do
    [ -e "$dst/$name" ] && continue
    if [ "$FIX" = 1 ]; then cp -r "$src/$name" "$dst/$name"; echo "  + copied $d/$name"
    else echo "::error::.claude/$d/$name is missing (exists in templates/.claude/$d)"; fail=1; fi
  done < <(ls -A "$src")

  while IFS= read -r name; do
    [ -e "$src/$name" ] && continue
    echo "::warning::.claude/$d/$name has no counterpart in templates/.claude/$d (repo-only?)"
  done < <(ls -A "$dst")

  # content drift, ignoring the generated model: line
  while IFS= read -r name; do
    [ -f "$src/$name" ] || continue
    [ -f "$dst/$name" ] || continue
    if ! diff -q <(strip_generated "$src/$name") <(strip_generated "$dst/$name") >/dev/null; then
      if [ "$FIX" = 1 ]; then cp "$src/$name" "$dst/$name"; echo "  ~ updated $d/$name"
      else echo "::error::.claude/$d/$name differs from templates/.claude/$d/$name"; fail=1; fi
    fi
  done < <(ls -A "$src")
done

if [ "$fail" = 0 ]; then echo "roster in sync (.claude <-> templates/.claude)"
else echo; echo "Fix with: bash .aiflow/roster-drift.sh --fix"; fi
exit $fail
