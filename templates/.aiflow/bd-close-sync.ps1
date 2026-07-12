# aiflow bd-close-sync - run AFTER a Beads issue is closed locally.
# Honours the rule: on every local issue close, ASK whether to push and whether to
# dolt-sync the configured remote (github/gitlab/custom). Never pushes silently.
#
# Usage:  powershell -File .aiflow/bd-close-sync.ps1 <issue-id>
# Agents: the CLAUDE.md par.Beads-sync rule tells the agent to call this after `bd close`.
$ErrorActionPreference = 'Continue'

$issue = if ($args.Count -ge 1) { $args[0] } else { "<closed>" }
$cfgPath = ".aiflow/config.json"

function Have($name) { return [bool](Get-Command $name -ErrorAction SilentlyContinue) }
function Cfg($path) {
  if (-not (Test-Path $cfgPath)) { return $null }
  try {
    $cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json
    $node = $cfg
    foreach ($p in $path -split '\.') { if ($null -eq $node) { return $null }; $node = $node.$p }
    return $node
  } catch { return $null }
}

if (-not (Cfg "sync.askOnClose")) { Write-Output "sync-on-close disabled in $cfgPath"; exit 0 }
$remoteType = Cfg "remote.type"; if (-not $remoteType) { $remoteType = "github" }
if ($remoteType -eq "none") { Write-Output "no remote configured; nothing to sync"; exit 0 }

function Ask-YN($prompt) {
  $a = Read-Host "  $prompt (y/n) [y]"
  if (-not $a) { return $true }
  return $a -match '^[Yy]'
}

Write-Output "Beads issue $issue closed locally."

# 1) push the git branch (issue JSONL + code)
if ((Test-Path .git) -and (Ask-YN "Push the current branch to '$remoteType'?")) {
  git pull --rebase *> $null
  git push
  if ($LASTEXITCODE -ne 0) { Write-Output "  ! git push failed (resolve, then push manually)" }
}

# 2) dolt-sync the Beads DB with the remote (issues live in Dolt; refs/dolt/data on origin).
#    PULL BEFORE PUSH so we merge teammates' issue changes instead of clobbering them.
if ((Have bd) -and (Ask-YN "Dolt-sync Beads issues with the remote now?")) {
  bd dolt pull *> $null
  if ($LASTEXITCODE -ne 0) { Write-Output "  ! bd dolt pull failed - resolve conflicts, then push" }
  bd dolt push *> $null
  if ($LASTEXITCODE -ne 0) { Write-Output "  ! bd dolt push failed - run 'bd dolt pull' (merge) then 'bd dolt push' manually" }
}

Write-Output "done."
