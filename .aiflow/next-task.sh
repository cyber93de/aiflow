#!/usr/bin/env bash
# Pick the next Beads task to work on, by the AGENTS.md §4b selection order.
# Usage: next-task.sh [--after <bead-id>] [--unassigned] [--claim] [--json]
#
#   --after <id>   prefer a bead discovered from <id> (the task just closed) — the
#                  "natural continuation" rule; otherwise ignored
#   --unassigned   only beads nobody has claimed (team setups; see AGENTS.md §4a)
#   --claim        claim the chosen bead (bd update <id> --claim) before printing it
#   --json         print the whole bead as JSON instead of "<id>  <title>"
#
# Exit codes: 0 a task was chosen · 1 error (no bd / no jq) · 3 queue empty (nothing
# actionable). 3 is separate on purpose: an empty queue is a legitimate end of session,
# an error is not, and a caller in a loop must be able to tell them apart.
#
# Ranking (AGENTS.md §4b): priority asc → unblocks-most desc → continuation of --after →
# oldest first. Epic/workstream affinity is NOT ranked here: `bd ready --json` carries no
# epic field, so that rule stays with the agent, which can read the descriptions.
set -uo pipefail

AFTER=""; CLAIM=0; AS_JSON=0; READY_ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --after)      AFTER="${2:-}"; shift 2 ;;
    --unassigned) READY_ARGS+=(--unassigned); shift ;;
    --claim)      CLAIM=1; shift ;;
    --json)       AS_JSON=1; shift ;;
    -h|--help)    sed -n '2,14p' "$0"; exit 0 ;;
    *)            echo "unknown option: $1" >&2; exit 1 ;;
  esac
done

command -v bd >/dev/null 2>&1 || { echo "bd (beads) not installed — see 'aiflow doctor'" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq not installed — see 'aiflow doctor'" >&2; exit 1; }

# bash 3.2 (macOS): an empty array under `set -u` expands as an unbound variable
ready="$(bd ready --json ${READY_ARGS[@]+"${READY_ARGS[@]}"} 2>/dev/null)" || ready=""
[ -n "$ready" ] || { echo "queue empty: no ready tasks" >&2; exit 3; }

chosen="$(printf '%s' "$ready" | jq -c --arg after "$AFTER" '
  (if type == "array" then . else (.issues // []) end)
  | map(. + {
      _cont: (if $after != "" and (((.dependencies // []) | map(.depends_on_id) | index($after)) != null)
              then 0 else 1 end)
    })
  | sort_by(.priority // 9, -(.dependent_count // 0), ._cont, .created_at // "")
  | first // empty')"
[ -n "$chosen" ] || { echo "queue empty: no ready tasks" >&2; exit 3; }

id="$(printf '%s' "$chosen" | jq -r '.id')"
[ "$CLAIM" = 1 ] && bd update "$id" --claim >/dev/null 2>&1

if [ "$AS_JSON" = 1 ]; then
  printf '%s\n' "$chosen"
else
  printf '%s' "$chosen" | jq -r '"\(.id)  P\(.priority // "?")  \(.title)"'
fi
