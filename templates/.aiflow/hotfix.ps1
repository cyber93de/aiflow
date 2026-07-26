# Branch hotfix/<name> off main for an urgent production fix, and mark the in-progress
# version with a -HOTFIX suffix (mirrors how develop carries -SNAPSHOT). The suffix is
# stripped again by 'aiflow release' when the hotfix is merged back into main.
# Usage: aiflow hotfix <name>
$ErrorActionPreference = 'Stop'

$modelPath = ".aiflow/branching.json"
if (-not (Test-Path $modelPath)) { Write-Error "no branching model (.aiflow/branching.json). Configure via 'aiflow change-settings'."; exit 1 }
$model = Get-Content $modelPath -Raw | ConvertFrom-Json
if ($model.model -ne "gitflow") { Write-Error "hotfix/* is only defined for the gitflow branching model."; exit 1 }

$name = if ($args.Count -ge 1) { $args[0] } else { "" }
if (-not $name) { Write-Error "usage: aiflow hotfix <name>"; exit 1 }
$branch = "hotfix/$name"

if ((git status --porcelain)) { Write-Error "working tree not clean - commit/stash first."; exit 1 }
$cur = (git branch --show-current).Trim()
if ($cur -ne "main") { Write-Error "checkout 'main' before starting a hotfix. On: $cur"; exit 1 }
git show-ref --verify --quiet "refs/heads/$branch"
if ($LASTEXITCODE -eq 0) { Write-Error "branch '$branch' already exists."; exit 1 }

$newVer = (& powershell -NoProfile -File .aiflow/version.ps1 start-hotfix).Trim()
if ($LASTEXITCODE -ne 0) { exit 1 }

git switch -q -c $branch
Set-Content -Path VERSION -Value $newVer -NoNewline
git add VERSION
$env:AIFLOW_ALLOW_DIRECT_PUSH = "1"; $env:AIFLOW_SKIP_VERIFY = "1"
git commit -q -m "chore: start hotfix $newVer"
Write-Output ">> branched $branch from main, VERSION -> $newVer"
Write-Output "   fix the issue, then merge $branch -> main and run 'aiflow release --yes' to cut the patch release."
