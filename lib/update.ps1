# aiflow update - self-update the aiflow installation (AIFLOW_HOME) to the latest release.
#  - Git checkout (AIFLOW_HOME/.git exists): git pull --ff-only origin main.
#  - Archive install (no .git, e.g. installed from a downloaded release zip): checks the GitHub
#    Releases API for a newer version, downloads the windows archive, verifies it against the
#    published SHA256SUMS.txt, and installs it over AIFLOW_HOME.
# Only touches the aiflow install itself. For a single project's copied templates, see
# `aiflow project-update`.
$ErrorActionPreference = 'Stop'

$AIFLOW_HOME = if ($env:AIFLOW_HOME) { $env:AIFLOW_HOME } else { Split-Path -Parent $PSScriptRoot }
$GITHUB_REPO = "cyber93de/aiflow"
$verFile = Join-Path $AIFLOW_HOME 'VERSION'
$OLD_VER = if (Test-Path $verFile) { (Get-Content $verFile -TotalCount 1).Trim() } else { "0.0.0" }

function Test-IsNewer($a, $b) {
  if ($a -eq $b) { return $false }
  try { return ([version]($a -replace '[^0-9.]', '')) -gt ([version]($b -replace '[^0-9.]', '')) }
  catch { return $a -ne $b }
}

# GitHub API/download can fail purely on a TLS revocation-check timeout behind some corporate
# proxies/AV - mirrors curl's --ssl-revoke-best-effort on the bash side by not hard-failing on it.
[System.Net.ServicePointManager]::CheckCertificateRevocationList = $false
$UA = @{ "User-Agent" = "aiflow-update" }

function Invoke-Dl($uri) {
  return (Invoke-WebRequest -Uri $uri -UseBasicParsing -Headers $UA).Content
}
function Invoke-DlFile($uri, $outFile) {
  Invoke-WebRequest -Uri $uri -OutFile $outFile -UseBasicParsing -Headers $UA | Out-Null
}

$NEW_VER = $OLD_VER

if (Test-Path (Join-Path $AIFLOW_HOME '.git')) {
  $status = & git -C $AIFLOW_HOME status --porcelain 2>$null
  if ($status) {
    [Console]::Error.WriteLine("aiflow install has local changes - refusing to update. Commit/stash in $AIFLOW_HOME first.")
    exit 1
  }
  Write-Output ">> updating aiflow ($AIFLOW_HOME, git checkout)..."
  & git -C $AIFLOW_HOME fetch --tags origin *> $null
  if ($LASTEXITCODE -ne 0) { [Console]::Error.WriteLine("fetch failed"); exit 1 }
  & git -C $AIFLOW_HOME pull --ff-only origin main
  if ($LASTEXITCODE -ne 0) { [Console]::Error.WriteLine("update failed (not fast-forward?) - resolve manually in $AIFLOW_HOME"); exit 1 }
  $NEW_VER = if (Test-Path $verFile) { (Get-Content $verFile -TotalCount 1).Trim() } else { "0.0.0" }
} else {
  Write-Output ">> checking latest release for $GITHUB_REPO (archive install: $AIFLOW_HOME)..."

  $relJson = $null
  try { $relJson = Invoke-Dl "https://api.github.com/repos/$GITHUB_REPO/releases/latest" }
  catch { [Console]::Error.WriteLine("could not reach the GitHub releases API - check network/rate limits"); exit 1 }

  $rel = $relJson | ConvertFrom-Json
  $LATEST_TAG = $rel.tag_name
  if (-not $LATEST_TAG) { [Console]::Error.WriteLine("no releases found for $GITHUB_REPO"); exit 1 }
  $LATEST_VER = $LATEST_TAG -replace '^v', ''

  if (-not (Test-IsNewer $LATEST_VER $OLD_VER)) {
    Write-Output ">> already on latest (aiflow $OLD_VER)."
    exit 0
  }

  $OSNAME = "windows"; $EXT = "zip"
  $ASSET = "aiflow-$LATEST_VER-$OSNAME.$EXT"
  $SUMS = "aiflow-$LATEST_VER-SHA256SUMS.txt"
  $BASE_URL = "https://github.com/$GITHUB_REPO/releases/download/$LATEST_TAG"
  $TMP = Join-Path ([System.IO.Path]::GetTempPath()) ("aiflow-update-" + [System.Guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Force -Path $TMP | Out-Null

  try {
    Write-Output "   downloading $ASSET..."
    try { Invoke-DlFile "$BASE_URL/$ASSET" (Join-Path $TMP $ASSET) }
    catch { [Console]::Error.WriteLine("download failed: $BASE_URL/$ASSET"); exit 1 }
    try { Invoke-DlFile "$BASE_URL/$SUMS" (Join-Path $TMP $SUMS) }
    catch { [Console]::Error.WriteLine("download failed: $BASE_URL/$SUMS"); exit 1 }

    Write-Output "   verifying checksum..."
    $sumsLine = Get-Content (Join-Path $TMP $SUMS) | Where-Object { $_ -match [regex]::Escape($ASSET) + '$' } | Select-Object -First 1
    $EXPECTED = if ($sumsLine) { ($sumsLine -split '\s+')[0] } else { "" }
    if (-not $EXPECTED) { [Console]::Error.WriteLine("no checksum entry for $ASSET in $SUMS"); exit 1 }
    $ACTUAL = (Get-FileHash -Path (Join-Path $TMP $ASSET) -Algorithm SHA256).Hash.ToLower()
    if ($EXPECTED.ToLower() -ne $ACTUAL) {
      [Console]::Error.WriteLine("checksum mismatch for $ASSET (expected $EXPECTED, got $ACTUAL) - aborting")
      exit 1
    }

    Write-Output "   extracting..."
    $extractDir = Join-Path $TMP 'extracted'
    New-Item -ItemType Directory -Force -Path $extractDir | Out-Null
    Expand-Archive -Path (Join-Path $TMP $ASSET) -DestinationPath $extractDir -Force

    $STAGE = Join-Path $extractDir "aiflow-$LATEST_VER"
    if (-not (Test-Path $STAGE)) { [Console]::Error.WriteLine("unexpected archive layout (no aiflow-$LATEST_VER/ directory)"); exit 1 }

    Write-Output "   installing into $AIFLOW_HOME..."
    # clean bin/ and lib/ first: a plain overlay would leave files from the previous
    # version's layout behind (e.g. lib/*.sh surviving an update to an OS-scoped
    # .ps1-only windows archive - aiflow-cv7). templates/ and top-level files ship
    # complete in every archive and are fully overwritten anyway.
    Remove-Item -Path (Join-Path $AIFLOW_HOME 'bin'), (Join-Path $AIFLOW_HOME 'lib') -Recurse -Force -ErrorAction SilentlyContinue
    Copy-Item -Path (Join-Path $STAGE '*') -Destination $AIFLOW_HOME -Recurse -Force
    $NEW_VER = if (Test-Path $verFile) { (Get-Content $verFile -TotalCount 1).Trim() } else { "0.0.0" }
  } finally {
    Remove-Item -Path $TMP -Recurse -Force -ErrorAction SilentlyContinue
  }
}

if ($OLD_VER -eq $NEW_VER) {
  Write-Output ">> already on latest (aiflow $NEW_VER)."
} else {
  Write-Output ">> aiflow updated: $OLD_VER -> $NEW_VER"
  Write-Output "   Run 'aiflow project-update' in each project to pull the new templates in."
}
