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
function InstallUv {
  # same official installer lib/install-deps.sh runs on Windows (human-approved, aiflow-bkl)
  if (Have uv) { return }
  Say "installing uv (for graphify)"
  try { Invoke-RestMethod https://astral.sh/uv/install.ps1 | Invoke-Expression }
  catch { WarnMsg "install uv manually: https://docs.astral.sh/uv/" }
  $env:Path = "$env:USERPROFILE\.local\bin;$env:USERPROFILE\.cargo\bin;$env:Path"
}
function InstallRtk {
  Say "installing rtk"
  WarnMsg "install rtk manually: https://www.rtk-ai.app/docs/getting-started/installation/"
}
function InstallDolt {
  # Beads backend (bd runs a dolt sql-server)
  if (Have dolt) { return }
  Say "installing dolt (Beads database backend)"
  if (Have winget) { & winget install --id DoltHub.Dolt -e --source winget }
  elseif (Have scoop) { & scoop install dolt }
  else { WarnMsg "install dolt manually: https://docs.dolthub.com/introduction/installation" }
}
function InstallVcsCli {
  # remote host: new schema .remote.type, fallback to legacy string .vcs
  $rt = Cfg '.remote.type' ''
  if ([string]::IsNullOrEmpty($rt)) { $rt = Cfg '.vcs' 'github' }
  switch ($rt) {
    'github' {
      if (-not (Have gh)) {
        Say "GitHub CLI"
        if (Have winget) { & winget install --id GitHub.cli -e }
        elseif (Have scoop) { & scoop install gh }
        else { WarnMsg "install gh: https://cli.github.com" }
      }
    }
    'gitlab' {
      if (-not (Have glab)) {
        Say "GitLab CLI"
        if (Have winget) { & winget install --id glab.glab -e }
        elseif (Have scoop) { & scoop install glab }
        else { WarnMsg "install glab: https://gitlab.com/gitlab-org/cli" }
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
  if (Have winget) { & winget install --id Ollama.Ollama -e }
  elseif (Have scoop) { & scoop install ollama }
  else { WarnMsg "install ollama: https://ollama.com/download" }
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
  $installed = $false
  if (Have winget) { & winget install --id jqlang.jq -e; $installed = ($LASTEXITCODE -eq 0) }
  if (-not $installed -and (Have scoop)) { & scoop install jq; $installed = ($LASTEXITCODE -eq 0) }
  if (-not $installed) { WarnMsg "install jq: https://jqlang.github.io/jq/" }
}
InstallVcsCli   # gh or glab to match the configured VCS host

# ---- optional (only if enabled) ----
if ($TM -eq 'true' -and -not (Have task-master)) { Say "claude-task-master"; Npmg 'task-master-ai' | Out-Null }
if ($ROUTER -eq 'true' -and -not (Have ccr)) { Say "claude-code-router"; Npmg '@musistudio/claude-code-router' | Out-Null }
if ($RTK -eq 'true' -and -not (Have rtk)) { InstallRtk }
if ($GFY -eq 'true' -and -not (Have graphify)) {
  InstallUv
  Say "graphify"
  & uv tool install graphifyy 2>$null
  $gfyOk = $false
  if ($LASTEXITCODE -eq 0) { & graphify install 2>$null; $gfyOk = ($LASTEXITCODE -eq 0) }
  if (-not $gfyOk) { WarnMsg "install graphify manually: uv tool install graphifyy && graphify install" }
}
# cocoindex-code (semantic RAG code search; 'ccc' CLI + MCP; local embeddings, no API key)
if ($COCO -eq 'true' -and -not (Have ccc)) {
  InstallUv
  Say "cocoindex-code (ccc)"
  & uv tool install 'cocoindex-code[full]' 2>$null
  $cocoOk = ($LASTEXITCODE -eq 0)
  if (-not $cocoOk -and (Have pipx)) { & pipx install 'cocoindex-code[full]'; $cocoOk = ($LASTEXITCODE -eq 0) }
  if (-not $cocoOk) { WarnMsg "install cocoindex-code manually: uv tool install 'cocoindex-code[full]'  (or pipx)" }
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
Write-Output "Done. Verify with: aiflow doctor"
