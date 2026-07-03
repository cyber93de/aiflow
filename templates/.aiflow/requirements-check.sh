#!/usr/bin/env bash
# Advisory requirements-quality audit of the Beads backlog. Read-only.
# Prints a report and saves it to .aiflow/requirements-report.md. Changes nothing.
# Usage: aiflow requirements-check [bead-id]
set -uo pipefail

command -v claude >/dev/null 2>&1 || { echo "ERROR: 'claude' CLI not found" >&2; exit 3; }
if [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ] && [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo "note: no token in env; relying on stored Claude login." >&2
fi
command -v bd >/dev/null 2>&1 || echo "note: 'bd' not found - nothing to audit." >&2

TARGET="${1:-all open issues}"
REPORT=".aiflow/requirements-report.md"

read -r -d '' PROMPT <<EOF || true
Act as the requirements-check agent (see .claude/agents/requirements-check.md). Audit the Beads
backlog for description completeness and quality. Target: ${TARGET}.

Read the issues (bd list / bd show), .claude/memory/project-aim.md, CLAUDE.md §2, and
docs/architecture/. For each issue grade A/B/C/D with per-dimension scores (goal clarity,
acceptance criteria, scope, architecture fit, undescribed cases, dependencies), list concrete
missing items and undescribed cases (compare against the existing architecture/code), and give
2-5 clarifying questions. End with a backlog readiness table.

STRICTLY READ-ONLY: do not modify or create issues, comments, priorities, or code. Output the
full report as Markdown to stdout only.
EOF

echo ">> requirements-check: auditing backlog ($TARGET)..."
# Capture the report and also save it. Read-only audit; no edits expected.
claude -p "$PROMPT" --permission-mode acceptEdits | tee "$REPORT"
echo
echo ">> saved report -> $REPORT  (advisory only; nothing was changed)"
