# SessionStart hook: caveman terse-output mode, driven by .aiflow/config.json.
# enabled + mode (full|lite|ultra) come from config; full is the recommended default.
$ErrorActionPreference = 'SilentlyContinue'

$cfgPath = ".aiflow/config.json"
$on = $true
$mode = "full"
if (Test-Path $cfgPath) {
  try {
    $cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json
    if ($null -ne $cfg.caveman.enabled) { $on = [bool]$cfg.caveman.enabled }
    if ($cfg.caveman.mode) { $mode = $cfg.caveman.mode }
  } catch {}
}
if ($env:AIFLOW_CAVEMAN -eq "off") { $on = $false }
if (-not $on) { exit 0 }

$base = 'CAVEMAN MODE ACTIVE — communicate terse. Code, commits, PRs, security warnings: NORMAL prose. Persists until "stop caveman".'
switch ($mode) {
  "lite"  { Write-Output "$base (lite) Trim filler/pleasantries, keep articles + full sentences." }
  "ultra" { Write-Output "$base (ultra) Maximal compression: telegraphic, symbols ok, minimal words." }
  default { Write-Output "$base (full) Drop articles (a/an/the), filler, hedging. Fragments OK. Short synonyms." }
}
exit 0
