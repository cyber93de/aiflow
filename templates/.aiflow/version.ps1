# Version helper for the configured strategy (semver|calver). Reads/uses the VERSION file.
# Usage: version.ps1 current | release | next-dev [release-version]
$ErrorActionPreference = 'Stop'

$modelPath = ".aiflow/branching.json"
$strat = "semver"
if (Test-Path $modelPath) {
  try {
    $model = Get-Content $modelPath -Raw | ConvertFrom-Json
    if ($model.release.versionStrategy) { $strat = $model.release.versionStrategy }
  } catch {}
}
$ver = ""
if (Test-Path VERSION) { $ver = (Get-Content VERSION -Raw).Trim() }

$cmd = if ($args.Count -ge 1) { $args[0] } else { "current" }
$arg = if ($args.Count -ge 2) { $args[1] } else { "" }

if ($strat -eq "calver") {
  switch ($cmd) {
    "current"  { if ($ver) { Write-Output $ver } else { Write-Output (Get-Date -Format "yyyy.MM") } }
    "release"  { Write-Output (Get-Date -Format "yyyy.MM") }
    "next-dev" {
      $base = if ($arg) { $arg } else { Get-Date -Format "yyyy.MM" }
      $parts = $base.Split('.')
      $y = [int]$parts[0]; $m = [int]$parts[1] + 1
      if ($m -gt 12) { $m = 1; $y += 1 }
      Write-Output ("{0:D4}.{1:D2}" -f $y, $m)
    }
  }
} else {
  $base = if ($ver) { $ver } else { "0.1.0-SNAPSHOT" }
  $core = $base.Split('-')[0]
  $p = $core.Split('.')
  $ma = if ($p.Count -ge 1 -and $p[0]) { $p[0] } else { "0" }
  $mi = if ($p.Count -ge 2 -and $p[1]) { $p[1] } else { "1" }
  $pa = if ($p.Count -ge 3 -and $p[2]) { $p[2] } else { "0" }
  switch ($cmd) {
    "current"  { Write-Output $base }
    "release"  { Write-Output "$ma.$mi.$pa" }
    "next-dev" {
      $rel = if ($arg) { $arg } else { "$ma.$mi.$pa" }
      $rp = $rel.Split('.')
      $a = $rp[0]; $b = [int]$rp[1];
      Write-Output "$a.$($b + 1).0-SNAPSHOT"
    }
  }
}
