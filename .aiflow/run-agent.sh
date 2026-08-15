#!/usr/bin/env bash
# Generic headless runner: run a named aiflow agent over the whole project.
# The agent's behaviour (what it scans, what it may write) is defined in
# .claude/agents/<name>.md — this just invokes it. Usage: run-agent.sh <agent> [focus...]
set -uo pipefail

AGENT="${1:?usage: run-agent.sh <agent-name> [focus]}"; shift || true
FOCUS="$*"

command -v claude >/dev/null 2>&1 || { echo "ERROR: 'claude' CLI not found" >&2; exit 3; }
if [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ] && [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo "note: no token in env; relying on stored Claude login." >&2
fi
[ -f ".claude/agents/$AGENT.md" ] || echo "note: .claude/agents/$AGENT.md not found; relying on the agent name." >&2

MODE="${RALPH_PERMISSION_MODE:-acceptEdits}"
PROMPT="Act as the ${AGENT} agent defined in .claude/agents/${AGENT}.md and follow that definition exactly, operating over the whole project. ${FOCUS:+Focus on: ${FOCUS}. }Strictly obey the agent's rules about what it may modify — most auditor agents only create Beads issues and must not change code or other issues. Finish with the agent's specified summary."

echo ">> running ${AGENT}..."
claude -p "$PROMPT" --permission-mode "$MODE"
echo ">> ${AGENT} done."
