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
    else
      # No config (or no jq) to read: fall back to Claude Code, same as the .ps1 twin. Leaving
      # --agent off entirely made ralph pick its own default, which differed per install.
      AGENT_FLAG=(--agent claude-code)
    fi
    ;;
esac

read -r -d '' GUARD <<'EOF' || true

--- AIFLOW CONTEXT (ralph's own prompt template adds the completion-promise instruction -
don't duplicate it here, that only confuses where the tag ends up) ---
You run unattended in a loop. Each iteration starts fresh: you see your own previous work only in
the files, in git history, and in Beads. Beads IS your memory across iterations - keep it current
or the next iteration repeats your work.

Beads protocol (mandatory, every run):
1. FIRST iteration: if TASK is a bead id, claim it - `bd update <id> --claim`. If TASK is free
   text, create the bead first with acceptance criteria and claim it:
   `bd create --title="..." --description="..." --acceptance="..." --type=task` then `--claim`.
2. EVERY iteration: re-read your state before doing anything - `bd show <id>` - and record what
   you did at the end - `bd update <id> --notes "iteration N: <what changed, what is left>"`.
3. Work you discover but must not do here: `bd create ... --deps discovered-from:<id>`. Never
   silently widen scope.
4. LAST iteration: only close when the acceptance criteria are demonstrably met -
   `bd close <id> --reason "how each AC was verified"` - then emit the completion promise.
   If you are blocked, write the blocker into the bead before emitting the abort promise.

Make concrete progress toward the task, respecting AGENTS.md: section 2 architecture rules (a task
that does not fit is NOT implemented as-is - record the blocker and stop), section 3 Google style,
sections 3a/3b/3c quality gates (tests, logging, REST, database). Commit referencing the bead id.
Never invent scope beyond the acceptance criteria.
EOF

echo ">> ralph (open-ralph-wiggum): ${AGENT_FLAG[1]:-default agent from config}, max $MAX iterations"
exec ralph "TASK: ${PROMPT}
${GUARD}" \
  --completion-promise COMPLETE \
  --abort-promise BLOCKED \
  --max-iterations "$MAX" \
  "${AGENT_FLAG[@]}" \
  "$@"
