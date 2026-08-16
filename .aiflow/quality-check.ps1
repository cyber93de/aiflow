# Headless whole-project quality/refactoring audit. Files [technical issue] Beads issues.
# Usage: aiflow quality-check
$ErrorActionPreference = 'Stop'

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) { Write-Error "ERROR: 'claude' CLI not found"; exit 3 }
if (-not $env:CLAUDE_CODE_OAUTH_TOKEN -and -not $env:ANTHROPIC_API_KEY) {
  Write-Output "note: no token in env; relying on stored Claude login."
}
if (-not (Get-Command bd -ErrorAction SilentlyContinue)) { Write-Output "note: 'bd' not found - findings can't be filed as Beads issues." }

$mode = if ($env:RALPH_PERMISSION_MODE) { $env:RALPH_PERMISSION_MODE } else { "acceptEdits" }

$prompt = @'
Act as the quality-check agent (see .claude/agents/quality-check.md). Audit the WHOLE repository for
code quality and refactoring needs: dead/orphaned code, now-simplifiable code (e.g. left over after
a dependency or case was removed), duplication, excessive complexity, and inconsistencies. Use the
graphify graph for real usage and call graphs.

For every justifiable finding, file ONE Beads issue:
  title:    "[technical issue] <short description>"
  priority: broad risk/blocking -> P1, meaningful cleanup -> P2, minor -> P3 (P0 only if it breaks
            things); use `bd create ... -p <0-3>` (run `bd create --help` to confirm the flag).
            The PO will re-prioritise - pick a sensible default.
  body:     impact, file:line, suggested refactor, rough effort (S/M/L), risk.
Before filing, run `bd list` and skip findings already covered by an open issue whose title starts
with "[technical issue]" (no duplicates).

Do NOT refactor or modify any project code or other issues. Only read code and create
[technical issue] beads. Finish with a summary table (impact | location | title | bead id) and
totals. If the code is clean, say so explicitly.
'@

Write-Output ">> quality-check: auditing whole project for refactoring needs..."
& claude -p $prompt --permission-mode $mode
Write-Output ">> quality-check done. Review new beads: bd list | grep '\[technical issue\]'"
