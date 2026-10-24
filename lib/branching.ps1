# Derive the git branching governance model from .aiflow/config.json -> .git.
# Writes .aiflow/branching.json (machine-readable, the section 8 result), docs/branching.md
# (human-readable), ensures permanent branches exist, and seeds VERSION when releasing.
# Enforcement is done by the pre-push hook (reads branching.json). Idempotent.
$ErrorActionPreference = 'Stop'

$CFG = ".aiflow/config.json"
if (-not (Test-Path $CFG)) { exit 0 }
$cfgObj = $null
try { $cfgObj = Get-Content $CFG -Raw | ConvertFrom-Json } catch { exit 0 }
if (-not $cfgObj) { exit 0 }

function Write-JsonFile($path, $obj) {
  $json = $obj | ConvertTo-Json -Depth 20
  $full = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $path))
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($full, $json, $utf8NoBom)
}

# Null-check only (NOT jq's `//` semantics): an explicitly-set `false` must survive the
# default instead of being collapsed to it (aiflow-5qe - lib/branching.sh fixed the same way).
function Get-JVal($obj, $path, $default) {
  $cur = $obj
  foreach ($seg in $path -split '\.') {
    if ($null -eq $cur) { break }
    $cur = $cur.$seg
  }
  if ($null -eq $cur) { return $default }
  return $cur
}

$MODEL = Get-JVal $cfgObj "git.model" "none"
if ($MODEL -eq "none") {
  Remove-Item -Path ".aiflow/branching.json" -Force -ErrorAction SilentlyContinue
  Write-Output "  branching: none (no governance)"
  exit 0
}
$STRICT = [bool](Get-JVal $cfgObj "git.strict" $false)
$PRONLY = [bool](Get-JVal $cfgObj "git.prOnly" $false)
$AUTOREL = [bool](Get-JVal $cfgObj "git.autoRelease" $false)
$VER = Get-JVal $cfgObj "git.versionStrategy" "none"
$TAGS = [bool](Get-JVal $cfgObj "git.releaseTags" $true)
$CHORE = [bool](Get-JVal $cfgObj "git.chore" $false)

New-Item -ItemType Directory -Force -Path ".aiflow", "docs" | Out-Null

# ---- .aiflow/branching.json (governance descriptor) ----
$branchTypes = @()
if ($MODEL -eq "gitflow") { $branchTypes = @("feature/*", "bugfix/*", "hotfix/*") }
if ($CHORE) { $branchTypes = @($branchTypes) + "chore/*" }

$allowedCreations = @()
if ($MODEL -eq "gitflow") {
  $allowedCreations = @(
    [pscustomobject]@{ type = "feature/*"; from = @("develop") },
    [pscustomobject]@{ type = "bugfix/*"; from = @("develop") },
    [pscustomobject]@{ type = "hotfix/*"; from = @("main") }
  )
} else {
  $allowedCreations = @([pscustomobject]@{ type = "<any temporary>"; from = @("develop") })
}
if ($CHORE) { $allowedCreations = @($allowedCreations) + [pscustomobject]@{ type = "chore/*"; from = @("develop", "main") } }

$allowedMerges = @(
  [pscustomobject]@{ from = "develop"; to = "main" },
  [pscustomobject]@{ from = "main"; to = "develop" }
)
if ($MODEL -eq "gitflow") {
  $allowedMerges = @($allowedMerges) + @(
    [pscustomobject]@{ from = "feature/*"; to = "develop" },
    [pscustomobject]@{ from = "bugfix/*"; to = "develop" },
    [pscustomobject]@{ from = "hotfix/*"; to = "main" },
    [pscustomobject]@{ from = "hotfix/*"; to = "develop" }
  )
}
if ($CHORE) {
  $allowedMerges = @($allowedMerges) + @(
    [pscustomobject]@{ from = "chore/*"; to = "develop" },
    [pscustomobject]@{ from = "chore/*"; to = "main" }
  )
}

$mainRestricted = $null
if ($MODEL -eq "gitflow") {
  $mainRestricted = [pscustomobject]@{ onlyFrom = @("develop", "hotfix/*", "chore/*"); forbidden = @("feature/*", "bugfix/*") }
}

$pullRequests = if ($PRONLY) {
  [pscustomobject]@{
    required          = $true
    protectedBranches = @("main", "develop")
    rules             = @("no direct push to protected branches", "merge only via Pull Request", "PR must pass validation")
  }
} else {
  [pscustomobject]@{ required = $false }
}

$release = if ($AUTOREL) {
  [pscustomobject]@{
    auto            = $true
    manualConfirm   = $true
    triggers        = @("merge develop -> main (minor release, strips -SNAPSHOT)", "merge hotfix/* -> main (patch release)")
    excludesTrigger = @("chore/* -> main")
    versionStrategy = $VER
    tag             = [pscustomobject]@{ enabled = $TAGS; format = if ($VER -eq "calver") { "{version}" } else { "v{version}" } }
  }
} else {
  [pscustomobject]@{ auto = $false }
}

$branchNaming = if ($MODEL -eq "gitflow" -and $STRICT) { "enforced" } else { "not enforced (temporary branches may use any name)" }

$branchingObj = [pscustomobject][ordered]@{
  model             = $MODEL
  strict            = $STRICT
  permanentBranches = @("main", "develop")
  branchTypes       = $branchTypes
  allowedCreations  = $allowedCreations
  allowedMerges     = $allowedMerges
  mainRestricted    = $mainRestricted
  pullRequests      = $pullRequests
  release           = $release
  branchNaming      = $branchNaming
}

Write-JsonFile ".aiflow/branching.json" $branchingObj
$strictS = $STRICT.ToString().ToLower(); $prOnlyS = $PRONLY.ToString().ToLower()
$autoRelS = $AUTOREL.ToString().ToLower(); $choreS = $CHORE.ToString().ToLower()
Write-Output "  branching: $MODEL (strict=$strictS prOnly=$prOnlyS autoRelease=$autoRelS ver=$VER chore=$choreS) -> .aiflow/branching.json"

# ---- docs/branching.md (human-readable) ----
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# Branching model: $MODEL")
$lines.Add("")
$lines.Add("Generated by aiflow from .aiflow/config.json. Change via ``aiflow change-settings``.")
$lines.Add("")
$lines.Add("- **Permanent branches:** main, develop")
$lines.Add("- **The mainline is named ``main``** - not ``master``. Every rule below, the pre-push hook,")
$lines.Add("  ``aiflow hotfix`` references ``main`` by name. A repo still on ``master``")
$lines.Add("  is renamed by ``aiflow apply`` (``git branch -m master main``); push it and switch the")
$lines.Add("  default branch on your remote, then delete the old ``master``.")
$lines.Add("- **Strict rules:** $strictS   **PR-only:** $prOnlyS   **chore/*:** $choreS")
$lines.Add("")
$lines.Add("## Allowed branch creation")
foreach ($c in $allowedCreations) { $lines.Add("- $($c.type) <- from: $($c.from -join ", ")") }
$lines.Add("")
$lines.Add("## Allowed merges")
foreach ($m in $allowedMerges) { $lines.Add("- $($m.from) -> $($m.to)") }
$lines.Add("")
if ($MODEL -eq "gitflow") {
  $lines.Add("## main is restricted")
  $lines.Add("- Only ``chore/*`` and ``hotfix/*`` may ever target ``main``.")
  $lines.Add("- ``feature/*`` and ``bugfix/*`` always target ``develop`` - never ``main``, directly or via PR.")
  $lines.Add("- Doc-only changes and CI/workflow-file-only changes (``.github/workflows/**``) count as ``chore/*``, not ``feature/*``.")
  $lines.Add("")
}
if ($PRONLY) {
  $lines.Add("## Pull requests")
  $lines.Add("- No direct push to main/develop; merge only via PR; PR must pass validation.")
  $lines.Add("")
}
$lines.Add("## Work and build flow")
$lines.Add("- Start each feature/bugfix from develop; build and validate it, then merge it into develop.")
$lines.Add("- Snapshot builds validate changes; they do not edit VERSION, tag, or publish a release.")
$lines.Add("- Promote develop to main only when explicitly requested, after the full checks pass.")
$lines.Add("- Ordinary agent work has no aiflow release step; maintainers handle publishing separately.")
$lines.Add("")
$lines.Add("Enforced locally by the ``pre-push`` git hook; enforce on the server with branch protection (``aiflow protect``).")

$mdContent = ($lines -join "`n") + "`n"
$mdFull = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) "docs/branching.md"))
[System.IO.File]::WriteAllText($mdFull, $mdContent, (New-Object System.Text.UTF8Encoding($false)))

# ---- legacy 'master' -> 'main' (aiflow-dpz) ----
# The whole governance above hard-codes 'main'. A repo sitting on 'master' would keep it as the
# active branch while we additionally branch 'main' off HEAD - two divergent lines, and every
# rule silently stops applying. So rename when it is unambiguous, and refuse when it is not.
if (Test-Path ".git") {
  & git rev-parse --verify HEAD *> $null
  if ($LASTEXITCODE -eq 0) {
    & git show-ref --verify --quiet "refs/heads/master"; $hasMaster = ($LASTEXITCODE -eq 0)
    & git show-ref --verify --quiet "refs/heads/main";   $hasMain   = ($LASTEXITCODE -eq 0)
    if ($hasMaster -and $hasMain) {
      Write-Output "  ! both 'master' and 'main' exist - aiflow governs 'main' only and will NOT touch 'master'."
      Write-Output "    Merge or delete 'master' yourself, then re-run 'aiflow apply'."
    } elseif ($hasMaster -and $env:AIFLOW_NO_BRANCH_RENAME -eq '1') {
      Write-Output "  ! branch is 'master' but AIFLOW_NO_BRANCH_RENAME=1 - governance expects 'main' and will not apply."
    } elseif ($hasMaster) {
      & git branch -m master main *> $null
      if ($LASTEXITCODE -eq 0) {
        Write-Output "  renamed branch master -> main (aiflow's branching model governs 'main')"
        & git remote get-url origin *> $null
        if ($LASTEXITCODE -eq 0) {
          Write-Output "    remote still has 'master'. Finish the migration yourself:"
          Write-Output "      git push -u origin main"
          Write-Output "      # switch the default branch to 'main' in your host's settings, then:"
          Write-Output "      git push origin --delete master"
        }
      } else {
        Write-Output "  ! could not rename 'master' -> 'main' - do it manually: git branch -m master main"
      }
    }
  }
}

# ---- ensure permanent branches exist (don't switch) ----
# If a remote-tracking ref already exists (origin/$b) but no local branch, create the local
# branch FROM origin/$b, not from current HEAD - origin/$b may have diverged from wherever
# you're currently checked out, and branching off HEAD would silently lose/ignore that history.
if (Test-Path ".git") {
  & git rev-parse --verify HEAD *> $null
  if ($LASTEXITCODE -eq 0) {
    foreach ($b in @("main", "develop")) {
      & git show-ref --verify --quiet "refs/heads/$b"
      if ($LASTEXITCODE -ne 0) {
        & git show-ref --verify --quiet "refs/remotes/origin/$b"
        if ($LASTEXITCODE -eq 0) {
          & git branch $b "origin/$b" *> $null
          if ($LASTEXITCODE -eq 0) { Write-Output "  created branch $b (tracking origin/$b)" }
        } else {
          & git branch $b *> $null
          if ($LASTEXITCODE -eq 0) { Write-Output "  created branch $b" }
        }
      }
    }
  }
}

# ---- seed VERSION for releases ----
if ($AUTOREL -and -not (Test-Path "VERSION")) {
  if ($VER -eq "calver") { $seed = Get-Date -Format "yyyy.MM" } else { $seed = "0.1.0-SNAPSHOT" }
  Set-Content -Path "VERSION" -Value $seed -NoNewline
  Write-Output "  seeded VERSION ($seed)"
}
