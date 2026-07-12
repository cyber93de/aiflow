# Cut a release per the branching model: set the release version on main, tag it, then
# bump develop to the next dev version. Run on main after merging develop -> main.
# Usage: aiflow release [--push]
$ErrorActionPreference = 'Stop'

$modelPath = ".aiflow/branching.json"
if (-not (Test-Path $modelPath)) { Write-Error "no branching model (.aiflow/branching.json). Configure via 'aiflow change-settings'."; exit 1 }
$model = Get-Content $modelPath -Raw | ConvertFrom-Json

if (-not ($model.release.auto -eq $true)) { Write-Error "auto-release is disabled in the branching model."; exit 1 }
$tagsEnabled = if ($null -eq $model.release.tag.enabled) { $true } else { $model.release.tag.enabled }
$strat = if ($model.release.versionStrategy) { $model.release.versionStrategy } else { "semver" }
$push = $args -contains "--push"

if ((git status --porcelain)) { Write-Error "working tree not clean - commit/stash first."; exit 1 }
$cur = (git branch --show-current).Trim()
if ($cur -ne "main") { Write-Error "checkout 'main' (after merging develop) before releasing. On: $cur"; exit 1 }

$rel = (& powershell -NoProfile -File .aiflow/version.ps1 release).Trim()
Write-Output ">> releasing $rel on main"
Set-Content -Path VERSION -Value $rel -NoNewline
git add VERSION
$env:AIFLOW_ALLOW_DIRECT_PUSH = "1"; $env:AIFLOW_SKIP_VERIFY = "1"
git commit -q -m "chore(release): $rel"

if ($tagsEnabled) {
  $tag = if ($strat -eq "calver") { $rel } else { "v$rel" }
  git tag -a $tag -m "release $rel"
  Write-Output "   tagged $tag"
}

$next = (& powershell -NoProfile -File .aiflow/version.ps1 next-dev $rel).Trim()
git show-ref --verify --quiet refs/heads/develop
if ($LASTEXITCODE -eq 0) {
  git switch -q develop
  Set-Content -Path VERSION -Value $next -NoNewline
  git add VERSION
  git commit -q -m "chore: start $next"
  git switch -q main
  Write-Output "   develop bumped to $next"
}

if ($push) {
  git push --follow-tags origin main develop
  if ($LASTEXITCODE -ne 0) {
    Write-Output "   ! push failed (protected branches usually need PR/CI; push tags/branches as your flow allows)"
  }
}
Write-Output ">> release done: main=$rel  develop=$next  (push with --push, or via your PR/CI flow)"
