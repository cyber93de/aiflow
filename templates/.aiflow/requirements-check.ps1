# Advisory requirements-quality audit of the Beads backlog. Read-only.
# Prints a report and saves it to .aiflow/requirements-report.md. Changes nothing.
# Usage: aiflow requirements-check [bead-id]
$ErrorActionPreference = 'Stop'

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) { Write-Error "ERROR: 'claude' CLI not found"; exit 3 }
if (-not $env:CLAUDE_CODE_OAUTH_TOKEN -and -not $env:ANTHROPIC_API_KEY) {
  Write-Output "note: no token in env; relying on stored Claude login."
}
if (-not (Get-Command bd -ErrorAction SilentlyContinue)) { Write-Output "note: 'bd' not found - nothing to audit." }

$target = if ($args.Count -ge 1) { $args[0] } else { "all open issues" }
$report = ".aiflow/requirements-report.md"

$prompt = @"
Act as the requirements-check agent (see .claude/agents/requirements-check.md). Audit the Beads
backlog for description completeness and quality. Target: $target.

Read the issues (bd list / bd show), .claude/memory/project-aim.md, CLAUDE.md par.2, and
docs/architecture/. For each issue grade A/B/C/D with per-dimension scores (goal clarity,
acceptance criteria, scope, architecture fit, undescribed cases, dependencies), list concrete
missing items and undescribed cases (compare against the existing architecture/code), and give
2-5 clarifying questions. End with a backlog readiness table.

STRICTLY READ-ONLY: do not modify or create issues, comments, priorities, or code. Output the
full report as Markdown to stdout only.
"@

Write-Output ">> requirements-check: auditing backlog ($target)..."
& claude -p $prompt --permission-mode acceptEdits | Tee-Object -FilePath $report
Write-Output ""
Write-Output ">> saved report -> $report  (advisory only; nothing was changed)"
