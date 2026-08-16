# Pick the next Beads task to work on, by the AGENTS.md 4b selection order.
# Usage: aiflow next [--after <bead-id>] [--unassigned] [--claim] [--json]
#        (direct: powershell -File .aiflow/next-task.ps1 [...])
#
#   --after <id>   prefer a bead discovered from <id> (the task just closed) - the
#                  "natural continuation" rule; otherwise ignored
#   --unassigned   only beads nobody has claimed (team setups; see AGENTS.md 4a)
#   --claim        claim the chosen bead (bd update <id> --claim) before printing it
#   --json         print the whole bead as JSON instead of "<id>  <title>"
#
# Exit codes: 0 a task was chosen, 1 error (no bd), 3 queue empty (nothing actionable).
# 3 is separate on purpose: an empty queue is a legitimate end of session, an error is not.
#
# Ranking (AGENTS.md 4b): priority asc, unblocks-most desc, continuation of --after, oldest
# first. Epic/workstream affinity is NOT ranked here: 'bd ready --json' carries no epic
# field, so that rule stays with the agent, which can read the descriptions.
$ErrorActionPreference = 'Stop'

$after = ""; $claim = $false; $asJson = $false; $readyArgs = @()
for ($i = 0; $i -lt $args.Count; $i++) {
  switch ($args[$i]) {
    "--after"      { $after = $args[$i + 1]; $i++ }
    "--unassigned" { $readyArgs += "--unassigned" }
    "--claim"      { $claim = $true }
    "--json"       { $asJson = $true }
    { $_ -in "-h", "--help" } { Get-Content $PSCommandPath | Select-Object -Skip 1 -First 14; exit 0 }
    default        { Write-Error "unknown option: $($args[$i])"; exit 1 }
  }
}

if (-not (Get-Command bd -ErrorAction SilentlyContinue)) {
  Write-Error "bd (beads) not installed - see 'aiflow doctor'"; exit 1
}

$raw = & bd ready --json @readyArgs 2>$null
if ($LASTEXITCODE -ne 0 -or -not $raw) { Write-Error "queue empty: no ready tasks"; exit 3 }
try { $parsed = ($raw | Out-String | ConvertFrom-Json) } catch { Write-Error "queue empty: no ready tasks"; exit 3 }
# bd may hand back a bare array or an object wrapping one
$items = if ($parsed -is [array]) { $parsed } elseif ($parsed.issues) { $parsed.issues } else { @($parsed) }
if (-not $items -or $items.Count -eq 0) { Write-Error "queue empty: no ready tasks"; exit 3 }

$ranked = $items | Sort-Object `
  @{ Expression = { if ($null -ne $_.priority) { [int]$_.priority } else { 9 } } }, `
  @{ Expression = { if ($null -ne $_.dependent_count) { [int]$_.dependent_count } else { 0 } }; Descending = $true }, `
  @{ Expression = {
       if ($after -and $_.dependencies -and ($_.dependencies | Where-Object { $_.depends_on_id -eq $after })) { 0 } else { 1 }
     } }, `
  @{ Expression = { "$($_.created_at)" } }
$chosen = @($ranked)[0]
if (-not $chosen) { Write-Error "queue empty: no ready tasks"; exit 3 }

if ($claim) { & bd update $chosen.id --claim *> $null }

if ($asJson) {
  $chosen | ConvertTo-Json -Depth 10 -Compress
} else {
  $p = if ($null -ne $chosen.priority) { $chosen.priority } else { "?" }
  Write-Output "$($chosen.id)  P$p  $($chosen.title)"
}
