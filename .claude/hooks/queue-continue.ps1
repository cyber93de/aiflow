# Stop hook: a finished task is not a finished session (AGENTS.md 4b).
# When the agent stops while ready Beads tasks remain, hand the next one back so the
# queue keeps moving without the user having to ask "what's next?".
#
# Blocks AT MOST ONCE per stop: Claude Code sets stop_hook_active on the re-entry, and
# the check below bails on it. That is the whole loop protection - the agent can always
# stop a second time, e.g. to state a legitimate reason from 4b.
#
# Opt out per project (.aiflow/config.json -> beads.queueMode = false) or per session
# (AIFLOW_QUEUE_MODE=off). Silent no-op outside a beads project.
$ErrorActionPreference = 'SilentlyContinue'

$payload = [Console]::In.ReadToEnd()
if ($payload) {
  try {
    $in = $payload | ConvertFrom-Json
    if ($in.stop_hook_active -eq $true) { exit 0 }
  } catch {}
}

if ($env:AIFLOW_QUEUE_MODE -eq 'off') { exit 0 }
if (-not (Test-Path .beads -PathType Container)) { exit 0 }
if (-not (Get-Command bd -ErrorAction SilentlyContinue)) { exit 0 }
if (Test-Path .aiflow/config.json) {
  try {
    $cfg = Get-Content .aiflow/config.json -Raw | ConvertFrom-Json
    if ($null -ne $cfg.beads.queueMode -and $cfg.beads.queueMode -eq $false) { exit 0 }
  } catch {}
}

# next-task.ps1 exits 3 on an empty queue - the legitimate end of a session.
$next = & powershell -NoProfile -ExecutionPolicy Bypass -File .aiflow/next-task.ps1 2>$null
if ($LASTEXITCODE -ne 0 -or -not $next) { exit 0 }

$reason = @"
Ready Beads task remains: $next

Per AGENTS.md 4b the queue continues: claim it (bd update <id> --claim), work it to its
acceptance criteria, close it, then check again. Stop only when the queue is empty, the
rest is blocked, the user says stop, or you need a decision/credential only they can give
- in that case say which one applies.
"@

@{ decision = "block"; reason = $reason } | ConvertTo-Json -Compress
exit 0
