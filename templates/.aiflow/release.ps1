# Cut a release per the branching model: set the release version on main, tag it, then
# bump develop to the next dev version. Run on main after merging develop|hotfix/* -> main.
# Release kind is auto-detected from VERSION's suffix: "-SNAPSHOT" = minor release (develop),
# "-HOTFIX" = patch release (hotfix/*, started via 'aiflow hotfix'). Either way the suffix is
# stripped - main must never carry a -SNAPSHOT or -HOTFIX version. A hotfix release also merges
# the hotfix branch into develop so the fix isn't lost.
# Usage: aiflow release [--push] [--yes]
# Without --yes this prints a dry run only - releasing must always be a deliberate,
# user-approved action (agents: ask the user before adding --yes).
$ErrorActionPreference = 'Stop'

$modelPath = ".aiflow/branching.json"
if (-not (Test-Path $modelPath)) { Write-Error "no branching model (.aiflow/branching.json). Configure via 'aiflow change-settings'."; exit 1 }
$model = Get-Content $modelPath -Raw | ConvertFrom-Json

if (-not ($model.release.auto -eq $true)) { Write-Error "auto-release is disabled in the branching model."; exit 1 }
$tagsEnabled = if ($null -eq $model.release.tag.enabled) { $true } else { $model.release.tag.enabled }
$strat = if ($model.release.versionStrategy) { $model.release.versionStrategy } else { "semver" }
$push = $args -contains "--push"
$yes = ($args -contains "--yes") -or ($args -contains "-y")

if ((git status --porcelain)) { Write-Error "working tree not clean - commit/stash first."; exit 1 }
$cur = (git branch --show-current).Trim()
if ($cur -ne "main") { Write-Error "checkout 'main' (after merging develop or hotfix/*) before releasing. On: $cur"; exit 1 }

$curVer = if (Test-Path VERSION) { (Get-Content VERSION -Raw).Trim() } else { "" }
$isHotfix = $false
if ($strat -eq "semver") {
  if ($curVer -match '-HOTFIX$') { $isHotfix = $true }
  elseif ($curVer -match '-') { $isHotfix = $false }
  else { Write-Error "VERSION '$curVer' has no -SNAPSHOT/-HOTFIX suffix - nothing to release."; exit 1 }
}

$hotfixBranch = ""
if ($isHotfix) {
  $subj = (git log -1 --merges --pretty=%s 2>$null)
  # supports both local "git merge" ("Merge branch 'X'") and GitHub PR-merge subjects
  # ("Merge pull request #N from owner/X") - X may itself contain slashes (e.g. hotfix/foo).
  $candidate = $null
  if ($subj -match "^Merge branch '([^']*)'") {
    $candidate = $matches[1]
  } elseif ($subj -match "^Merge pull request #\d+ from [^/]+/(.*)$") {
    $candidate = $matches[1]
  }
  if ($candidate -and ($candidate -like "hotfix/*")) { $hotfixBranch = $candidate }
}

$rel = (& powershell -NoProfile -File .aiflow/version.ps1 release).Trim()
$next = (& powershell -NoProfile -File .aiflow/version.ps1 next-dev $rel).Trim()
$kind = if ($isHotfix) { "hotfix release (patch)" } else { "release" }

if (-not $yes) {
  Write-Output ">> DRY RUN - this would cut a ${kind}:"
  Write-Output "     $curVer  ->  $rel   (on main)"
  Write-Output "     develop bumped to: $next"
  if ($isHotfix -and $hotfixBranch) { Write-Output "     hotfix commits from '$hotfixBranch' will also be merged into develop" }
  Write-Output "   Releasing is a deliberate, user-approved action - re-run with --yes to actually release."
  Write-Output "   (aiflow agents: ask the user for explicit confirmation before adding --yes.)"
  exit 0
}

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

git show-ref --verify --quiet refs/heads/develop
if ($LASTEXITCODE -eq 0) {
  git switch -q develop
  if ($isHotfix -and $hotfixBranch) {
    $mergeRef = $null
    git show-ref --verify --quiet "refs/heads/$hotfixBranch"
    if ($LASTEXITCODE -eq 0) { $mergeRef = $hotfixBranch }
    else {
      # local branch is often already gone by now (e.g. GitHub's "delete branch on merge"
      # after a PR merge) - fall back to the remote-tracking ref so the fix still lands here.
      git show-ref --verify --quiet "refs/remotes/origin/$hotfixBranch"
      if ($LASTEXITCODE -eq 0) { $mergeRef = "origin/$hotfixBranch" }
    }
    if ($mergeRef) {
      # VERSION always conflicts here (hotfix carries X.Y.Z-HOTFIX, develop its own -SNAPSHOT) -
      # expected and harmless since VERSION gets overwritten with $next right after anyway.
      # Any other conflict is real and aborts for manual resolution.
      $ok = $true
      git merge --no-ff --no-commit -q $mergeRef *> $null
      if ($LASTEXITCODE -ne 0) { $ok = $false }
      if (-not $ok) {
        $conflicted = (git diff --name-only --diff-filter=U) -join "`n"
        if ($conflicted -eq "VERSION") {
          git checkout --ours VERSION
          git add VERSION
          $ok = $true
        }
      }
      if ($ok) {
        git commit -q -m "merge $hotfixBranch into develop (hotfix from release $rel)"
        Write-Output "   merged $hotfixBranch into develop"
      } else {
        Write-Output "   ! could not auto-merge $hotfixBranch into develop (conflicts beyond VERSION) - resolve manually, then bump VERSION yourself."
        git merge --abort
        git switch -q main
        exit 1
      }
    }
  }
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
