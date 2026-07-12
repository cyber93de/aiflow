# Run the headless Ralph loop in a local container - works with Podman OR Docker.
# Usage: docker/run.ps1 "<prompt or bead id>"
#   Override the engine with $env:AIFLOW_CONTAINER = "podman" | "docker"
$ErrorActionPreference = 'Stop'

if (Test-Path .env) {
  Get-Content .env | ForEach-Object {
    if ($_ -match '^\s*#') { return }
    if ($_ -match '^\s*([^=]+?)\s*=\s*(.*)$') {
      $name = $matches[1].Trim(); $val = $matches[2].Trim().Trim('"')
      if ($name) { [Environment]::SetEnvironmentVariable($name, $val, 'Process') }
    }
  }
}

$prompt = ($args -join " ").Trim()
if (-not $prompt) { Write-Error 'usage: docker/run.ps1 "<prompt>"'; exit 1 }
$img = "aiflow-ralph:local"

$engine = $env:AIFLOW_CONTAINER
if (-not $engine) {
  if (Get-Command podman -ErrorAction SilentlyContinue) { $engine = "podman" }
  elseif (Get-Command docker -ErrorAction SilentlyContinue) { $engine = "docker" }
  else { Write-Error "Need Podman or Docker. Install one, or set `$env:AIFLOW_CONTAINER."; exit 1 }
}
if (-not (Get-Command $engine -ErrorAction SilentlyContinue)) { Write-Error "$engine not found on PATH"; exit 1 }

Write-Output ">> using container engine: $engine"
& $engine build -t $img -f docker/Dockerfile .
& $engine run --rm -it `
  -v "${PWD}:/work" `
  -e ANTHROPIC_API_KEY -e CLAUDE_CODE_OAUTH_TOKEN -e GITHUB_TOKEN `
  -e RALPH_MAX_ITERATIONS -e RALPH_TIMEOUT_SECONDS -e RALPH_PERMISSION_MODE `
  $img $prompt
