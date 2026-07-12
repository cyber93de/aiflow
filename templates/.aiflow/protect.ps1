# Apply server-side branch protection on the host so the PR-only / merge rules are actually
# enforced for everyone (the pre-push hook only protects the local user). GitHub via gh.
# Usage: aiflow protect
$ErrorActionPreference = 'Stop'

$modelPath = ".aiflow/branching.json"; $cfgPath = ".aiflow/config.json"
if (-not (Test-Path $modelPath)) { Write-Error "no branching model. Run 'aiflow change-settings' first."; exit 1 }
$model = Get-Content $modelPath -Raw | ConvertFrom-Json

$vcs = "github"
if (Test-Path $cfgPath) {
  try { $cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json; if ($cfg.vcs) { $vcs = $cfg.vcs } } catch {}
}
$prOnly = $model.pullRequests.required -eq $true
$branches = $model.pullRequests.protectedBranches
if (-not $branches -or $branches.Count -eq 0) { $branches = @("main", "develop") }

if ($vcs -ne "github") {
  Write-Output "Server-side protection for '$vcs' is not automated. Configure it in your host:"
  Write-Output "  - require PRs to $($branches -join ', '), block direct pushes, require CI to pass."
  exit 0
}
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { Write-Error "gh (GitHub CLI) not found. Install it, or set protection in the GitHub UI."; exit 1 }
$repo = (gh repo view --json nameWithOwner -q .nameWithOwner 2>$null)
if (-not $repo) { Write-Error "not a GitHub repo / not authed (gh auth login)."; exit 1 }

foreach ($b in $branches) {
  Write-Output ">> protecting ${repo}:$b"
  gh api -X PUT "repos/$repo/branches/$b/protection" `
    -H "Accept: application/vnd.github+json" `
    -f "required_pull_request_reviews[required_approving_review_count]=1" `
    -F "required_status_checks[strict]=true" `
    -f "required_status_checks[contexts][]=ci" `
    -F "enforce_admins=true" `
    -F "restrictions=null" *> $null
  if ($LASTEXITCODE -eq 0) {
    Write-Output "   PR required + CI required on $b"
  } else {
    Write-Output "   ! failed for $b (need admin + repo:admin token scope)"
  }
}
if (-not $prOnly) { Write-Output "note: PR-only is OFF in the model; protection applied anyway for safety." }
Write-Output ">> done. Verify in repo Settings -> Branches."
