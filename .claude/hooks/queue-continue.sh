#!/usr/bin/env bash
# Stop hook: a finished task is not a finished session (AGENTS.md §4b).
# When the agent stops while ready Beads tasks remain, hand the next one back so the
# queue keeps moving without the user having to ask "what's next?".
#
# Blocks AT MOST ONCE per stop: Claude Code sets stop_hook_active on the re-entry, and
# the first line below bails on it. That is the whole loop protection — the agent can
# always stop a second time, e.g. to state a legitimate reason from §4b.
#
# Opt out per project (.aiflow/config.json → beads.queueMode = false) or per session
# (AIFLOW_QUEUE_MODE=off). Silent no-op outside a beads project.
set -uo pipefail
have() { command -v "$1" >/dev/null 2>&1; }

payload="$(cat 2>/dev/null || true)"
if have jq && [ -n "$payload" ]; then
  [ "$(printf '%s' "$payload" | jq -r '.stop_hook_active // false' 2>/dev/null)" = "true" ] && exit 0
fi

[ "${AIFLOW_QUEUE_MODE:-}" = "off" ] && exit 0
[ -d .beads ] || exit 0
have bd || exit 0
if have jq && [ -f .aiflow/config.json ]; then
  [ "$(jq -r 'if .beads.queueMode == null then true else .beads.queueMode end' .aiflow/config.json 2>/dev/null)" = "false" ] && exit 0
fi

# next-task.sh exits 3 on an empty queue — the legitimate end of a session.
next="$(bash .aiflow/next-task.sh 2>/dev/null)" || exit 0
[ -n "$next" ] || exit 0

reason="Ready Beads task remains: ${next}

Per AGENTS.md §4b the queue continues: claim it (bd update <id> --claim), work it to its
acceptance criteria, close it, then check again. Stop only when the queue is empty, the
rest is blocked, the user says stop, or you need a decision/credential only they can give
— in that case say which one applies."

if have jq; then
  jq -nc --arg r "$reason" '{decision:"block", reason:$r}'
else
  # no jq: exit 2 + stderr is the other documented way to block
  printf '%s\n' "$reason" >&2
  exit 2
fi
exit 0
