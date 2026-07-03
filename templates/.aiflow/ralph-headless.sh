#!/usr/bin/env bash
# Headless Ralph Wiggum loop: iterate Claude Code until COMPLETE or BLOCKED.
# Usage: aiflow ralph "<prompt or bead id>"
#        .aiflow/ralph-headless.sh "<prompt>"
# Reads tokens/tuning from env (.env is loaded by `aiflow ralph`).
set -uo pipefail

PROMPT="${*:-}"
if [ -z "$PROMPT" ]; then echo "usage: aiflow ralph \"<prompt or bead id>\"" >&2; exit 2; fi

MAX="${RALPH_MAX_ITERATIONS:-50}"
TIMEOUT="${RALPH_TIMEOUT_SECONDS:-3600}"
MODE="${RALPH_PERMISSION_MODE:-acceptEdits}"
RESULT="result.json"
START="$(date +%s)"

# Auth: an env token (CLAUDE_CODE_OAUTH_TOKEN or ANTHROPIC_API_KEY) OR an existing
# interactive login (stored OAuth creds, like a normal `claude` session) both work.
command -v claude >/dev/null 2>&1 || { echo "ERROR: 'claude' CLI not found" >&2; exit 3; }
if [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ] && [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo "note: no token in env; relying on stored Claude login. For CI set a token (see .env)." >&2
fi

read -r -d '' GUARD <<'EOF' || true

--- RALPH LOOP PROTOCOL ---
You run unattended in a loop. Each iteration:
1. If result.json exists, read it to recover where you left off.
2. Make concrete progress toward the task. Respect CLAUDE.md (architecture, Google style,
   acceptance criteria, tests). Use Beads (bd) to track state.
3. Before finishing THIS iteration, OVERWRITE result.json (valid JSON) with:
   { "status": "IN_PROGRESS" | "COMPLETE" | "BLOCKED",
     "summary": "<what changed this iteration>",
     "next": "<what to do next, or empty>",
     "blocker": "<why blocked, only if BLOCKED>" }
Rules: COMPLETE only when ALL acceptance criteria are met, tests pass, style/lint clean,
and the review gate would pass. BLOCKED if you need a human decision or missing access.
Never invent scope beyond the acceptance criteria. Commit your work (reference bead ids).
EOF

status="IN_PROGRESS"
for i in $(seq 1 "$MAX"); do
  now="$(date +%s)"
  if [ $((now - START)) -ge "$TIMEOUT" ]; then
    echo "{\"status\":\"BLOCKED\",\"blocker\":\"timeout after ${TIMEOUT}s\"}" > "$RESULT"
    status="BLOCKED"; break
  fi

  echo ">> Ralph iteration $i/$MAX  (elapsed $((now-START))s)"
  claude -p "TASK: ${PROMPT}
${GUARD}" \
    --permission-mode "$MODE" \
    --output-format json \
    >/dev/null 2>>".aiflow/ralph.log" || true

  if [ -f "$RESULT" ]; then
    if command -v jq >/dev/null 2>&1; then
      status="$(jq -r '.status // "IN_PROGRESS"' "$RESULT" 2>/dev/null)"
    else
      status="$(grep -o '"status"[^,}]*' "$RESULT" | head -n1 | sed 's/.*: *"//; s/"$//')"
    fi
  fi
  echo "   status=$status"
  case "$status" in COMPLETE|BLOCKED) break;; esac
done

echo "== Ralph finished: $status =="
[ -f "$RESULT" ] && cat "$RESULT"
case "$status" in
  COMPLETE) exit 0 ;;
  BLOCKED)  exit 1 ;;
  *)        exit 2 ;;  # ran out of iterations
esac
