#!/usr/bin/env bash
# Headless full-project security audit. Files Beads issues per finding.
# Usage: aiflow security-check    (or: bash .aiflow/security-check.sh)
set -uo pipefail

command -v claude >/dev/null 2>&1 || { echo "ERROR: 'claude' CLI not found" >&2; exit 3; }
if [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ] && [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo "note: no token in env; relying on stored Claude login." >&2
fi
command -v bd >/dev/null 2>&1 || echo "note: 'bd' not found - findings can't be filed as Beads issues." >&2

MODE="${RALPH_PERMISSION_MODE:-acceptEdits}"

read -r -d '' PROMPT <<'EOF' || true
Act as the security-advisor agent (see .claude/agents/security-advisor.md). Perform a full-project
security audit of THIS repository (the whole codebase, not just the diff), using the Anthropic
security-review methodology.

For every vulnerability you can justify:
- Determine severity: Critical, High, Medium, or Low.
- File ONE Beads issue:
    title:    "[security-advisor] <short description>"
    priority: Critical->P0, High->P1, Medium->P2, Low->P3   (use `bd create ... -p <0-3>`; run
              `bd create --help` first to confirm the flag)
    body:     severity, file:line, impact, recommended fix, CWE id if known.
- Before filing, run `bd list` and skip findings already covered by an open issue whose title
  starts with "[security-advisor]" (no duplicates).

Do NOT modify any project code. Only read code and create Beads issues.
Finish with a summary table (severity | location | title | bead id) and totals per severity.
If you find nothing, say so explicitly.
EOF

echo ">> security-advisor: scanning whole project..."
claude -p "$PROMPT" --permission-mode "$MODE"
echo ">> security-check done. Review new beads: bd list | grep '\[security-advisor\]'"
