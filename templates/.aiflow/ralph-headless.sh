#!/usr/bin/env bash
# Headless Ralph Wiggum loop via open-ralph-wiggum (github.com/Th0rgal/open-ralph-wiggum) -
# agent-agnostic: works with Claude Code, OpenAI Codex CLI, or GitHub Copilot CLI through a
# single --agent flag. ralph itself owns the outer loop (iterations, restart, promise
# detection, .ralph/ralph-history.json) - this script just builds the task prompt and picks a
# default agent from .aiflow/config.json's agents.* if the caller didn't pass --agent.
# Usage: aiflow ralph "<prompt or bead id>" [ralph flags..., e.g. --agent codex --tasks]
set -uo pipefail

PROMPT="${1:-}"; shift || true
if [ -z "$PROMPT" ]; then echo "usage: aiflow ralph \"<prompt or bead id>\" [ralph flags...]" >&2; exit 2; fi

command -v ralph >/dev/null 2>&1 || {
  echo "ERROR: 'ralph' CLI not found - npm i -g @th0rgal/ralph-wiggum (needs Bun: https://bun.sh)" >&2
  exit 3
}

MAX="${RALPH_MAX_ITERATIONS:-50}"

# Default --agent from .aiflow/config.json's agents.* (claude > codex > copilot priority)
# unless the caller already passed --agent explicitly.
AGENT_FLAG=()
case " $* " in
  *" --agent "*) : ;;
  *)
    if command -v jq >/dev/null 2>&1 && [ -f .aiflow/config.json ]; then
      if   [ "$(jq -r 'if .agents.claude == null then true else .agents.claude end'  .aiflow/config.json)" = true ]; then AGENT_FLAG=(--agent claude-code)
      elif [ "$(jq -r '.agents.codex   // false' .aiflow/config.json)" = true ]; then AGENT_FLAG=(--agent codex)
      elif [ "$(jq -r '.agents.copilot // false' .aiflow/config.json)" = true ]; then AGENT_FLAG=(--agent copilot)
      fi
    fi
    ;;
esac

read -r -d '' GUARD <<'EOF' || true

--- AIFLOW CONTEXT (ralph's own prompt template adds the completion-promise instruction -
don't duplicate it here, that only confuses where the tag ends up) ---
You run unattended in a loop; each iteration you see your own previous work in files and git
history. Make concrete progress toward the task, respecting AGENTS.md (architecture, Google
style, acceptance criteria, tests). Use Beads (bd) to track state; commit your work referencing
bead ids. Never invent scope beyond the acceptance criteria.
EOF

echo ">> ralph (open-ralph-wiggum): ${AGENT_FLAG[1]:-default agent from config}, max $MAX iterations"
exec ralph "TASK: ${PROMPT}
${GUARD}" \
  --completion-promise COMPLETE \
  --abort-promise BLOCKED \
  --max-iterations "$MAX" \
  "${AGENT_FLAG[@]}" \
  "$@"
