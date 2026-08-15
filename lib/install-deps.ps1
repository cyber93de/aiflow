# aiflow install-deps - install the toolchain so you don't have to pre-install anything.
# Installs ONLY tools that are (a) missing and (b) enabled in .aiflow/config.json
# (or everything with --all). User-space installers; Docker is never auto-installed.
$ErrorActionPreference = 'Continue'

function Have($name) { [bool](Get-Command $name -ErrorAction SilentlyContinue) }
function Say($msg) { Write-Output ">> $msg" }
function WarnMsg($msg) { [Console]::Error.WriteLine("  ! $msg") }

$All = $false
foreach ($a in $args) {
  if ($a -eq '--all') { $All = $true }
  elseif ($a -eq '--yes' -or $a -eq '-y') { $Yes = $true }
}

# this .ps1 twin only ships in the windows release archive - always windows.
$OS = 'windows'

function Cfg($jsonPath, $default) {
  if ((Have jq) -and (Test-Path '.aiflow/config.json')) {
    if ([string]::IsNullOrEmpty($default)) {
      # PowerShell's native-exe argument passing silently drops an EMPTY STRING argument
      # (unlike bash, which execs the argv array as-is) - '--arg d ""' would vanish and
      # shift every argument after it, so an empty default can't go through --arg at all.
      # '// empty' needs no default value argument, sidestepping the issue entirely.
      return (& jq -r "$jsonPath // empty" '.aiflow/config.json')
    }
    # --arg (not an embedded "..." in the filter text): a single argument containing literal
    # quote characters is also mangled by PowerShell's native-exe argument passing.
    return (& jq -r --arg d "$default" "$jsonPath // `$d" '.aiflow/config.json')
  }
  return $default
}

if ($All -or -not (Test-Path '.aiflow/config.json')) {
  $RTK = 'true'; $TM = 'true'; $ROUTER = 'true'; $GFY = 'true'
  $AGENT_CLAUDE = 'true'; $AGENT_COPILOT = 'true'; $AGENT_CODEX = 'true'
} else {
  $RTK = Cfg '.rtk.enabled' 'false'
  $TM = Cfg '.taskmaster.enabled' 'false'
  $ROUTER = Cfg '.router.enabled' 'false'
  $GFY = Cfg '.graphify.enabled' 'false'
  $AGENT_CLAUDE = Cfg '.agents.claude' 'true'
  $AGENT_COPILOT = Cfg '.agents.copilot' 'false'
  $AGENT_CODEX = Cfg '.agents.codex' 'false'
}
$OLLAMA = Cfg '.ollama.enabled' 'false'
$COCO = Cfg '.mcp.cocoindex' 'false'
if ($All) { $COCO = 'true' }
# CodexSaver needs a paid provider API key - never auto-enabled by --all, config opt-in only
$CODEXSAVER = Cfg '.codexsaver.enabled' 'false'
$CODEXSAVER_PROVIDER = Cfg '.codexsaver.provider' 'deepseek'
$CODEXSAVER_KEYENV = Cfg '.codexsaver.apiKeyEnv' 'DEEPSEEK_API_KEY'

function Npmg($pkg) {
  # install a global npm package
  if (-not (Have npm)) { WarnMsg "npm not found - install Node.js first (https://nodejs.org)"; return $false }
  & npm install -g $pkg 2>$null
  if ($LASTEXITCODE -ne 0) { WarnMsg "failed: npm i -g $pkg"; return $false }
  return $true
}
# ---- PATH + native toolchain ------------------------------------------------------------
# winget/scoop write the new binary's directory into the *registry* PATH; the already-running
# session never sees it, so a tool installed two lines up looks "missing" to the next check and
# to 'aiflow doctor' (aiflow-sx6). Rebuild $env:Path from Machine+User after each such install.
$script:NeedsRestart = @()
function Update-PathFromRegistry {
  $machine = [Environment]::GetEnvironmentVariable('PATH', 'Machine')
  $user = [Environment]::GetEnvironmentVariable('PATH', 'User')
  $merged = @($machine, $user) | Where-Object { $_ }
  if ($merged) { $env:Path = ($merged -join ';') }
}
function Install-WinPkg($cmdName, $wingetId, $scoopName) {
  $ok = $false
  if (Have winget) {
    & winget install --id $wingetId -e --source winget --accept-source-agreements --accept-package-agreements
    $ok = ($LASTEXITCODE -eq 0)
  }
  if (-not $ok -and (Have scoop)) { & scoop install $scoopName; $ok = ($LASTEXITCODE -eq 0) }
  if (-not $ok) { return $false }
  Update-PathFromRegistry
  if (-not (Have $cmdName)) { $script:NeedsRestart += $cmdName }
  return $true
}
# WSL is where native code gets compiled on Windows - never MinGW/MSYS2 (aiflow-sq3).
function Test-WslReady {
  if (-not (Have wsl)) { return $false }
  & wsl.exe -e true 2>$null
  return ($LASTEXITCODE -eq 0)
}
function Install-BuildToolchain {
  # only called when something actually needs a C/C++ compiler
  if (Test-WslReady) {
    & wsl.exe -e sh -c "command -v g++ >/dev/null" 2>$null
    if ($LASTEXITCODE -eq 0) { return $true }
    Say "installing build-essential inside WSL (native builds do NOT use MinGW)"
    & wsl.exe -e sh -c "sudo apt-get update -qq && sudo apt-get install -y build-essential"
    if ($LASTEXITCODE -ne 0) { WarnMsg "run inside WSL: sudo apt update && sudo apt install -y build-essential" }
    return $true
  }
  WarnMsg "no WSL - native builds need it. Admin PowerShell: wsl --install  then  wsl --install -d Ubuntu"
  WarnMsg "do NOT install MinGW/MSYS2 for this: https://cyber93de.github.io/aiflow/installation#windows-prerequisites-do-this-first"
  return $false
}

function InstallUv {
  # same official installer lib/install-deps.sh runs on Windows (human-approved, aiflow-bkl)
  if (Have uv) { return $true }
  Say "installing uv (for graphify / cocoindex-code)"
  try { Invoke-RestMethod https://astral.sh/uv/install.ps1 | Invoke-Expression }
  catch { WarnMsg "install uv manually: https://docs.astral.sh/uv/" }
  $env:Path = "$env:USERPROFILE\.local\bin;$env:USERPROFILE\.cargo\bin;$env:Path"
  Update-PathFromRegistry
  if (-not (Have uv)) { WarnMsg "uv still not on PATH after install - open a new shell, or add %USERPROFILE%\.local\bin to PATH"; return $false }
  return $true
}
function InstallRtk {
  # rtk-ai/rtk. There is no winget/scoop package; the upstream installer is a POSIX shell
  # script, so on Windows it runs through Git Bash. Verify instead of assuming (aiflow-3ds).
  Say "installing rtk"
  $sh = Get-Command bash -ErrorAction SilentlyContinue
  if ($sh) {
    & bash -lc "curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh" 2>$null
  }
  $env:Path = "$env:USERPROFILE\.rtk\bin;$env:USERPROFILE\.local\bin;$env:Path"
  Update-PathFromRegistry
  if (-not (Have rtk)) {
    WarnMsg "rtk install did not produce an 'rtk' on PATH. Get it from the repo:"
    WarnMsg "    https://github.com/rtk-ai/rtk        (clone + follow its README/install.sh)"
    WarnMsg "    docs: https://www.rtk-ai.app/docs/getting-started/installation/"
    return $false
  }
  return $true
}
function InstallGraphify {
  # PyPI package name is 'graphifyy' (two y's) - upstream repo: Graphify-Labs/graphify.
  # Errors used to be silenced, so a failure looked like success (aiflow-zw8).
  if (-not (InstallUv)) { return $false }
  Say "graphify (structural code graph)"
  & uv tool install graphifyy
  if ($LASTEXITCODE -ne 0) {
    WarnMsg "uv tool install graphifyy failed - retrying from the upstream repo"
    & uv tool install "git+https://github.com/Graphify-Labs/graphify"
    if ($LASTEXITCODE -ne 0) {
      WarnMsg "install graphify manually: https://github.com/Graphify-Labs/graphify"
      WarnMsg "    uv tool install graphifyy   ||   uv tool install git+https://github.com/Graphify-Labs/graphify"
      return $false
    }
  }
  $env:Path = "$env:USERPROFILE\.local\bin;$env:Path"
  if (-not (Have graphify)) { WarnMsg "graphify installed but not on PATH - add %USERPROFILE%\.local\bin (uv tool dir) to PATH"; return $false }
  & graphify install
  if ($LASTEXITCODE -ne 0) { WarnMsg "'graphify install' failed - run it manually once" }
  return $true
}
function InstallDolt {
  # Beads backend (bd runs a dolt sql-server)
  if (Have dolt) { return }
  Say "installing dolt (Beads database backend)"
  if (-not (Install-WinPkg dolt 'DoltHub.Dolt' 'dolt')) { WarnMsg "install dolt manually: https://docs.dolthub.com/introduction/installation" }
}
function InstallVcsCli {
  # remote host: new schema .remote.type, fallback to legacy string .vcs
  $rt = Cfg '.remote.type' ''
  if ([string]::IsNullOrEmpty($rt)) { $rt = Cfg '.vcs' 'github' }
  switch ($rt) {
    'github' {
      if (-not (Have gh)) {
        Say "GitHub CLI"
        if (-not (Install-WinPkg gh 'GitHub.cli' 'gh')) { WarnMsg "install gh: https://cli.github.com" }
      }
    }
    'gitlab' {
      if (-not (Have glab)) {
        Say "GitLab CLI"
        if (-not (Install-WinPkg glab 'glab.glab' 'glab')) { WarnMsg "install glab: https://gitlab.com/gitlab-org/cli" }
      }
    }
    'custom' {
      $baseUrl = Cfg '.remote.baseUrl' ''
      $tokenEnv = Cfg '.remote.tokenEnv' 'GIT_REMOTE_TOKEN'
      Say "custom remote ($baseUrl): using git + token in `$$tokenEnv; no host CLI auto-installed"
    }
    'none' { }
  }
}
function InstallOllama {
  if (Have ollama) { return }
  Say "installing ollama (local models)"
  if (-not (Install-WinPkg ollama 'Ollama.Ollama' 'ollama')) { WarnMsg "install ollama: https://ollama.com/download" }
}
function InstallBun {
  # runtime open-ralph-wiggum needs
  # same official installer lib/install-deps.sh runs on Windows (human-approved, aiflow-bkl)
  if (Have bun) { return }
  Say "installing bun (runtime for the Ralph loop)"
  try { Invoke-RestMethod https://bun.sh/install.ps1 | Invoke-Expression }
  catch { WarnMsg "install bun manually: https://bun.sh" }
  $env:Path = "$env:USERPROFILE\.bun\bin;$env:Path"
}
function InstallCodexsaver {
  # cost-aware MCP router for Codex CLI - no PyPI package, editable install from source.
  # Global by design (its own README): one clone shared across projects, like the tool itself
  # recommends. We never touch its own ~/.codex/config.toml write; our own .codex/config.toml
  # (in apply.ps1) just points at the stable script path it installs.
  if (Have codexsaver) { return }
  if (-not (Have python3) -and -not (Have python)) { WarnMsg "CodexSaver needs Python - install it first: https://python.org"; return }
  $py = if (Have python3) { 'python3' } else { 'python' }
  Say "installing CodexSaver (cost-aware Codex CLI router)"
  $dir = Join-Path $HOME '.local/share/aiflow/codexsaver'
  if (Test-Path (Join-Path $dir '.git')) {
    Push-Location $dir
    try { & git pull -q } catch {}
    Pop-Location
  } else {
    New-Item -ItemType Directory -Force -Path (Split-Path $dir) | Out-Null
    & git clone -q https://github.com/fendouai/CodexSaver $dir
    if ($LASTEXITCODE -ne 0) { WarnMsg "clone failed: https://github.com/fendouai/CodexSaver"; return }
  }
  Push-Location $dir
  & $py -m pip install -q -e .
  $pipOk = ($LASTEXITCODE -eq 0)
  Pop-Location
  if (-not $pipOk) { WarnMsg "pip install -e . failed in $dir"; return }
  Npmg '@earendil-works/pi-coding-agent' | Out-Null
  $keyVal = [Environment]::GetEnvironmentVariable($CODEXSAVER_KEYENV)
  if ($keyVal) {
    & codexsaver auth set --provider $CODEXSAVER_PROVIDER --api-key $keyVal 2>$null
    if ($LASTEXITCODE -ne 0) { WarnMsg "codexsaver auth set failed - run manually: codexsaver auth set --provider $CODEXSAVER_PROVIDER --api-key ..." }
  } else {
    WarnMsg "CodexSaver installed but no key in `$$CODEXSAVER_KEYENV - run: codexsaver auth set --provider $CODEXSAVER_PROVIDER --api-key ..."
  }
  & codexsaver install 2>$null
  if ($LASTEXITCODE -ne 0) { WarnMsg "run 'codexsaver install' manually to finish global setup" }
}

$AllNum = if ($All) { 1 } else { 0 }
Write-Output "aiflow install-deps (os=$OS, all=$AllNum)"
Write-Output "  enabled: rtk=$RTK task-master=$TM router=$ROUTER graphify=$GFY cocoindex=$COCO ollama=$OLLAMA"
Write-Output "  coding agent(s): claude=$AGENT_CLAUDE copilot=$AGENT_COPILOT codex=$AGENT_CODEX codexsaver=$CODEXSAVER"

# ---- coding agent CLIs (per agents.* config) ----
if ($AGENT_CLAUDE -eq 'true' -and -not (Have claude)) { Say "Claude Code"; Npmg '@anthropic-ai/claude-code' | Out-Null }
if ($AGENT_COPILOT -eq 'true' -and -not (Have copilot)) { Say "GitHub Copilot CLI"; Npmg '@github/copilot' | Out-Null }
if ($AGENT_CODEX -eq 'true' -and -not (Have codex)) {
  Say "OpenAI Codex CLI"
  $ok = Npmg '@openai/codex'
  if (-not $ok) { WarnMsg "install codex manually: npm i -g @openai/codex (or brew install --cask codex on macOS)" }
}
if ($AGENT_CODEX -eq 'true' -and $CODEXSAVER -eq 'true') { InstallCodexsaver }

InstallDolt   # Beads needs the dolt binary (runs a dolt sql-server)
if (-not (Have bd)) {
  Say "beads (bd)"
  $ok = Npmg '@beads/bd'
  if (-not $ok) {
    if (Have go) { & go install github.com/steveyegge/beads/cmd/bd@latest }
    else { WarnMsg "install beads manually: https://github.com/steveyegge/beads" }
  }
}
# Ralph loop (open-ralph-wiggum) - agent-agnostic, works with whichever CLI(s) are enabled above
if (-not (Have ralph)) { InstallBun; Say "ralph-wiggum (Ralph loop)"; Npmg '@th0rgal/ralph-wiggum' | Out-Null }
if (-not (Have jq)) {
  Say "jq"
  if (-not (Install-WinPkg jq 'jqlang.jq' 'jq')) { WarnMsg "install jq: https://jqlang.github.io/jq/" }
}
InstallVcsCli   # gh or glab to match the configured VCS host

# ---- optional (only if enabled) ----
if ($TM -eq 'true' -and -not (Have task-master)) { Say "claude-task-master"; Npmg 'task-master-ai' | Out-Null }
if ($ROUTER -eq 'true' -and -not (Have ccr)) { Say "claude-code-router"; Npmg '@musistudio/claude-code-router' | Out-Null }
if ($RTK -eq 'true' -and -not (Have rtk)) { InstallRtk }
if ($GFY -eq 'true' -and -not (Have graphify)) { InstallGraphify | Out-Null }
# cocoindex-code (semantic RAG code search; 'ccc' CLI + MCP; local embeddings, no API key).
# Builds native wheels -> needs a C/C++ toolchain, which on Windows means WSL, never MinGW.
if ($COCO -eq 'true' -and -not (Have ccc)) {
  if (InstallUv) {
    if (-not (Install-BuildToolchain)) { WarnMsg "cocoindex-code may fail to build without a C/C++ toolchain" }
  }
  Say "cocoindex-code (ccc)"
  & uv tool install 'cocoindex-code[full]'
  $cocoOk = ($LASTEXITCODE -eq 0)
  if (-not $cocoOk -and (Have pipx)) { & pipx install 'cocoindex-code[full]'; $cocoOk = ($LASTEXITCODE -eq 0) }
  if (-not $cocoOk) { WarnMsg "install cocoindex-code manually: uv tool install 'cocoindex-code[full]'  (or pipx)" }
  $env:Path = "$env:USERPROFILE\.local\bin;$env:Path"
  if (-not (Have ccc)) { WarnMsg "cocoindex-code installed but 'ccc' is not on PATH - add the uv tool dir (%USERPROFILE%\.local\bin)" }
}
if ($All -or $OLLAMA -eq 'true') {
  InstallOllama
  if ($OLLAMA -eq 'true' -and (Test-Path '.aiflow/config.json')) {
    try { & (Join-Path $PSScriptRoot 'ollama.ps1') pull 2>$null } catch {}
  }
}

# ---- never auto-installed ----
# A container engine is optional: the GitHub MCP and the headless Ralph container (docker/run.sh)
# work with EITHER Podman or Docker. Install one yourself if you want them.
if (-not (Have podman) -and -not (Have docker)) {
  WarnMsg "No container engine (Podman or Docker) found - needed for the GitHub MCP and headless container runs. Install Podman (https://podman.io) or Docker Desktop (https://www.docker.com/products/docker-desktop/)."
}

# re-apply so newly installed tools get wired (rtk hook etc.)
if (Test-Path '.aiflow/config.json') {
  try { & (Join-Path $PSScriptRoot 'apply.ps1') *> $null } catch {}
}
Write-Output ""
# Anything winget/scoop installed that a PATH refresh still couldn't surface only becomes
# usable in a NEW shell - say so instead of letting the next command report it as missing.
if ($script:NeedsRestart.Count -gt 0) {
  Write-Output ("  ! installed but not yet on this shell's PATH: " + ($script:NeedsRestart -join ' '))
  Write-Output "    Open a NEW terminal (VS Code: fully restart it) before running 'aiflow doctor'."
  Write-Output ""
}
Write-Output "Done. Verify with: aiflow doctor"
