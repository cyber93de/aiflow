# aiflow upgrade - update the bundled toolchain to latest (deps, not aiflow itself).
# Best-effort: each tool guarded; skips what isn't installed.
$ErrorActionPreference = 'Continue'

function Test-Cmd($name) { return [bool](Get-Command $name -ErrorAction SilentlyContinue) }
function Step($msg) { Write-Output ">> $msg" }

if (Test-Cmd npm) {
  Step "npm globals (claude-code, task-master-ai, claude-code-router)"
  & npm install -g '@anthropic-ai/claude-code@latest' '@musistudio/claude-code-router@latest' 'task-master-ai@latest' *> $null
}

if (Test-Cmd uv) {
  Step "graphify (uv)"
  & uv tool upgrade graphifyy *> $null
  if ($LASTEXITCODE -ne 0) { & uv tool install graphifyy *> $null }
}

if (Test-Cmd bd) {
  Step "beads (bd)"
  & bd version *> $null
  & bd self-update *> $null
  if ($LASTEXITCODE -ne 0) {
    & bd update *> $null
    if ($LASTEXITCODE -ne 0) { Write-Output "  (update bd via its installer if needed)" }
  }
}

if (Test-Cmd rtk) {
  Step "rtk"
  & rtk upgrade *> $null
  if ($LASTEXITCODE -ne 0) {
    & rtk update *> $null
    if ($LASTEXITCODE -ne 0) { Write-Output "  (update rtk via its installer)" }
  }
}

# claude-code-templates is always run via npx@latest -> nothing to pin.
Step "rebuild graphify graph (if enabled)"
if ((Test-Path '.aiflow/config.json') -and (Test-Cmd jq) -and (Test-Cmd graphify)) {
  $enabled = & jq -r '.graphify.enabled' '.aiflow/config.json'
  if ($enabled -eq 'true') { & graphify build . *> $null }
}

Step "re-applying project config"
if (Test-Path '.aiflow/config.json') {
  try {
    $applyPs1 = Join-Path $PSScriptRoot 'apply.ps1'
    & $applyPs1
  } catch {}
}
Write-Output "upgrade done. Run 'aiflow doctor' to verify versions."
