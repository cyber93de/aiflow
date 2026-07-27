# aiflow ollama - manage local Ollama models from .aiflow/config.json.
# Subcommands:
#   pull            pull every model listed in config (.ollama.models)
#   add <model>     add a model to config and pull it
#   list            list installed models
#   models          print the configured models
# Local models need no API key. They are wired into claude-code-router by apply.ps1
# so easy/background tasks actually route to them (aiflow shell --router).
$ErrorActionPreference = 'SilentlyContinue'

$CFG = ".aiflow/config.json"

function Test-Have($name) { [bool](Get-Command $name -ErrorAction SilentlyContinue) }

function Get-Cfg {
  if (Test-Path $CFG) {
    try { return (Get-Content $CFG -Raw | ConvertFrom-Json) } catch { return $null }
  }
  return $null
}

function Set-JsonProperty($obj, $name, $value) {
  if ($obj.PSObject.Properties.Match($name).Count -gt 0) { $obj.$name = $value }
  else { $obj | Add-Member -NotePropertyName $name -NotePropertyValue $value }
}

function Write-JsonFile($path, $obj) {
  $json = $obj | ConvertTo-Json -Depth 20
  $full = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $path))
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($full, $json, $utf8NoBom)
}

$script:cfg = Get-Cfg
$Url = if ($script:cfg -and $script:cfg.ollama -and $script:cfg.ollama.url) { $script:cfg.ollama.url } else { "http://localhost:11434" }

function Get-ModelsFromCfg {
  if ($script:cfg -and $script:cfg.ollama -and $script:cfg.ollama.models) { return @($script:cfg.ollama.models) }
  return @()
}

function Invoke-EnsureOllama {
  if (-not (Test-Have ollama)) {
    Write-Output ">> installing ollama"
    $installed = $false
    if (Test-Have winget) {
      & winget install --id Ollama.Ollama -e
      if ($LASTEXITCODE -eq 0) { $installed = $true }
    }
    if (-not $installed -and (Test-Have scoop)) {
      & scoop install ollama
      if ($LASTEXITCODE -eq 0) { $installed = $true }
    }
    if (-not $installed) { Write-Output "  install ollama: https://ollama.com/download" }
  }
  if (-not (Test-Have ollama)) { Write-Output "  ! ollama not available; skipping"; return $false }
  $reachable = $false
  try {
    Invoke-WebRequest -Uri "$Url/api/tags" -UseBasicParsing -TimeoutSec 3 | Out-Null
    $reachable = $true
  } catch { $reachable = $false }
  if (-not $reachable) {
    Start-Process -FilePath "ollama" -ArgumentList "serve" -WindowStyle Hidden
    Start-Sleep -Seconds 2
  }
  return $true
}

$cmd = if ($args.Count -ge 1) { $args[0] } else { "pull" }
$rest = if ($args.Count -ge 2) { $args[1..($args.Count - 1)] } else { @() }

switch ($cmd) {
  "models" { Get-ModelsFromCfg | ForEach-Object { Write-Output $_ } }
  "list" { if (Invoke-EnsureOllama) { & ollama list } }
  "add" {
    $m = if ($rest.Count -ge 1) { $rest[0] } else { "" }
    if (-not $m) { [Console]::Error.WriteLine("usage: aiflow ollama add <model>"); exit 2 }
    if (-not (Test-Path $CFG)) { [Console]::Error.WriteLine("$CFG not found"); exit 1 }
    $raw = Get-Content $CFG -Raw | ConvertFrom-Json
    if ($raw.PSObject.Properties.Match('ollama').Count -eq 0) {
      $raw | Add-Member -NotePropertyName ollama -NotePropertyValue ([pscustomobject]@{})
    }
    Set-JsonProperty $raw.ollama "enabled" $true
    $existing = @()
    if ($raw.ollama.models) { $existing = @($raw.ollama.models) }
    $updated = @(@($existing + $m) | Sort-Object -Unique)
    Set-JsonProperty $raw.ollama "models" $updated
    Write-JsonFile $CFG $raw
    Write-Output "  added $m to $CFG"
    if (Invoke-EnsureOllama) { & ollama pull $m }
    & powershell -NoProfile -File (Join-Path $PSScriptRoot 'apply.ps1') *> $null
  }
  "pull" {
    $models = Get-ModelsFromCfg
    if ($models.Count -eq 0) { Write-Output "  no ollama models in $CFG (add with: aiflow ollama add <model>)"; exit 0 }
    if (-not (Invoke-EnsureOllama)) { exit 0 }
    foreach ($m in $models) {
      if (-not $m) { continue }
      Write-Output ">> ollama pull $m"
      & ollama pull $m
      if ($LASTEXITCODE -ne 0) { Write-Output "  ! failed to pull $m" }
    }
  }
  default { [Console]::Error.WriteLine("usage: aiflow ollama [pull|add <model>|list|models]"); exit 2 }
}
