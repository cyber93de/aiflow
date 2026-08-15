# Headless full-project security audit. Files Beads issues per finding.
# Usage: aiflow security-check    (or: powershell -File .aiflow/security-check.ps1)
$ErrorActionPreference = 'Stop'

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) { Write-Error "ERROR: 'claude' CLI not found"; exit 3 }
if (-not $env:CLAUDE_CODE_OAUTH_TOKEN -and -not $env:ANTHROPIC_API_KEY) {
  Write-Output "note: no token in env; relying on stored Claude login."
}
if (-not (Get-Command bd -ErrorAction SilentlyContinue)) { Write-Output "note: 'bd' not found - findings can't be filed as Beads issues." }

$mode = if ($env:RALPH_PERMISSION_MODE) { $env:RALPH_PERMISSION_MODE } else { "acceptEdits" }

$prompt = @'
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
'@

Write-Output ">> security-advisor: scanning whole project..."
& claude -p $prompt --permission-mode $mode
Write-Output ">> security-check done. Review new beads: bd list | grep '\[security-advisor\]'"
