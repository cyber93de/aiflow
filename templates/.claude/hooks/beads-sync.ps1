# SessionStart hook: pull the latest shared Beads issues so team members never start
# from a stale issue graph. Safe + non-blocking: only runs when a remote exists, never
# fails the session, never pushes (push is a deliberate act - see 'aiflow sync' / close-sync).
$ErrorActionPreference = 'SilentlyContinue'

function Have($name) { return [bool](Get-Command $name -ErrorAction SilentlyContinue) }

if (-not (Test-Path .beads -PathType Container)) { exit 0 }
if (-not (Have bd)) { exit 0 }
git rev-parse --is-inside-work-tree *> $null
if ($LASTEXITCODE -ne 0) { exit 0 }
git remote get-url origin *> $null
if ($LASTEXITCODE -ne 0) { exit 0 }

if (Test-Path .aiflow/config.json) {
  try {
    $cfg = Get-Content .aiflow/config.json -Raw | ConvertFrom-Json
    if ($null -ne $cfg.sync.pullOnStart -and $cfg.sync.pullOnStart -eq $false) { exit 0 }
  } catch {}
}

& bd dolt pull *> $null
if ($LASTEXITCODE -eq 0) {
  Write-Output "beads: pulled latest shared issues (bd dolt pull)"
} else {
  Write-Output "beads: could not pull shared issues - run 'aiflow sync' (resolve conflicts if any)"
}
exit 0
