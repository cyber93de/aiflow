# aiflow change-settings - re-adjust .aiflow/config.json, then re-apply. Project-scoped.
$ErrorActionPreference = 'Continue'

$AIFLOW_HOME = if ($env:AIFLOW_HOME) { $env:AIFLOW_HOME } else { Split-Path -Parent $PSScriptRoot }
$CFG = ".aiflow/config.json"
if (-not (Test-Path $CFG)) { [Console]::Error.WriteLine("no $CFG here - run 'aiflow init' first"); exit 1 }

$cfgObj = $null
try { $cfgObj = Get-Content $CFG -Raw | ConvertFrom-Json } catch { $cfgObj = $null }
function J($path) {
  $cur = $cfgObj
  foreach ($seg in ($path.TrimStart('.') -split '\.')) {
    if ($null -eq $cur) { return '' }
    $cur = $cur.$seg
  }
  if ($null -eq $cur) { return '' }
  if ($cur -is [bool]) { return $(if ($cur) { 'true' } else { 'false' }) }
  return [string]$cur
}

function Write-JsonFile($path, $obj) {
  $json = $obj | ConvertTo-Json -Depth 20
  $full = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $path))
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($full, $json, $utf8NoBom)
}

$NoTokenSave = $false
foreach ($a in $args) {
  if ($a -eq '--no-token-saving') { $NoTokenSave = $true }
  else { [Console]::Error.WriteLine("unknown flag: $a"); exit 2 }
}

function Ask($prompt, $d) {
  $a = Read-Host "  $prompt [$d]"
  if ([string]::IsNullOrEmpty($a)) { return $d }
  return $a
}
function AskYn($prompt, $d) {
  $a = Read-Host "  $prompt (y/n) [$d]"
  if ([string]::IsNullOrEmpty($a)) { $a = $d }
  if ($a -match '^[Yy]') { return 'true' }
  elseif ($a -match '^[Nn]') { return 'false' }
  elseif ($a -eq 'true' -or $a -eq 'false') { return $a }
  else { return $d }
}
function Dyn($v) { if ($v -eq 'true') { 'y' } else { 'n' } }

Write-Output "Change settings (Enter keeps current):"
if ($NoTokenSave) {
  Write-Output "  --no-token-saving: caveman + rtk switched OFF (full, unfiltered output)."
  $CAVE_ON = 'false'
  $CAVE_MODE = J '.caveman.mode'
  if (-not $CAVE_MODE) { $CAVE_MODE = 'full' }
  $RTK_ON = 'false'
} else {
  $CAVE_ON = AskYn 'caveman (terse output)?' (Dyn (J '.caveman.enabled'))
  $CAVE_MODE = Ask 'caveman mode (full/lite/ultra)' (J '.caveman.mode')
  $RTK_ON = AskYn 'rtk CLI-output filtering?' (Dyn (J '.rtk.enabled'))
}
$GRAPHIFY_ON = AskYn 'graphify structural code graph?' (Dyn (J '.graphify.enabled'))
$COCO_ON = AskYn 'cocoindex-code semantic RAG search?' (Dyn (J '.mcp.cocoindex'))
$TM_ON = AskYn 'claude-task-master?' (Dyn (J '.taskmaster.enabled'))
$FS_ON = AskYn 'filesystem MCP?' (Dyn (J '.mcp.filesystem'))
$CTX7_ON = AskYn 'context7 MCP (live library docs)?' (Dyn (J '.mcp.context7'))

# memory + graph intensity
$MEM_ON = AskYn 'persistent memory?' (Dyn (J '.memory.enabled'))
$MEM_GRAPH = J '.memory.graph'
if (-not $MEM_GRAPH) { $MEM_GRAPH = 'false' }
$MEM_INT = J '.memory.intensity'
if (-not $MEM_INT) { $MEM_INT = 'normal' }
if ($MEM_ON -eq 'true') {
  $MEM_GRAPH = AskYn 'graph memory (learn codebase into knowledge graph)?' (Dyn $MEM_GRAPH)
  $MEM_INT = Ask 'memory learning intensity (aggressive/normal/light)' $MEM_INT
}

# which coding agent(s) this project targets
$CUR_AGENT_CLAUDE = J '.agents.claude'
if (-not $CUR_AGENT_CLAUDE) { $CUR_AGENT_CLAUDE = 'true' }
$AGENT_CLAUDE = AskYn 'Claude Code (full feature set)?' (Dyn $CUR_AGENT_CLAUDE)
$AGENT_COPILOT = AskYn 'GitHub Copilot (AGENTS.md + .vscode/mcp.json)?' (Dyn (J '.agents.copilot'))
$AGENT_CODEX = AskYn 'OpenAI Codex CLI (AGENTS.md + .codex/config.toml)?' (Dyn (J '.agents.codex'))

# model routing: cheap-model default for audit-only subagents (Claude Code only)
$MODELROUTING_DEF = J '.modelRouting.enabled'
if (-not $MODELROUTING_DEF) { $MODELROUTING_DEF = 'true' }
$MODELROUTING_ON = AskYn 'model routing (route the 5 audit-only subagents to haiku)?' (Dyn $MODELROUTING_DEF)

# CodexSaver: optional cost-aware MCP router for Codex CLI
$CODEXSAVER_ON = 'false'
$CODEXSAVER_PROVIDER = J '.codexsaver.provider'
if (-not $CODEXSAVER_PROVIDER) { $CODEXSAVER_PROVIDER = 'deepseek' }
$CODEXSAVER_KEYENV = J '.codexsaver.apiKeyEnv'
if (-not $CODEXSAVER_KEYENV) { $CODEXSAVER_KEYENV = 'DEEPSEEK_API_KEY' }
if ($AGENT_CODEX -eq 'true') {
  $CODEXSAVER_ON = AskYn 'CodexSaver (cost-aware Codex CLI routing)?' (Dyn (J '.codexsaver.enabled'))
  if ($CODEXSAVER_ON -eq 'true') {
    $CODEXSAVER_PROVIDER = Ask 'CodexSaver provider' $CODEXSAVER_PROVIDER
    $CODEXSAVER_KEYENV = Ask 'Env var holding the provider API key' $CODEXSAVER_KEYENV
  }
}

# Claude auth (token-based)
$CLAUDE_AUTH = Ask 'Claude auth (apikey/oauth)' (J '.claude.auth')
if (-not $CLAUDE_AUTH) { $CLAUDE_AUTH = 'apikey' }

# local version control
$VCS_SYS = Ask 'Local version control (git/svn/none)' (J '.vcs.system')
if (-not $VCS_SYS) { $VCS_SYS = 'git' }

# remote host (token-based only)
Write-Output "  github|github-enterprise|gitlab|gitlab-self|bitbucket|forgejo|gitea|custom|none"
$REMOTE_TYPE = Ask 'Remote type' (J '.remote.type')
if (-not $REMOTE_TYPE) { $REMOTE_TYPE = 'github' }
$REMOTE_URL = J '.remote.baseUrl'; $REMOTE_API = J '.remote.api'; $REMOTE_TOKENENV = J '.remote.tokenEnv'; $REMOTE_MCP = J '.remote.mcp'
switch ($REMOTE_TYPE) {
  'github' { $REMOTE_URL = 'https://github.com'; $REMOTE_API = 'github-api'; $REMOTE_TOKENENV = 'GITHUB_TOKEN'; $REMOTE_MCP = 'github' }
  'github-enterprise' { $REMOTE_URL = Ask 'GHE base URL' $REMOTE_URL; $REMOTE_API = 'github-api'; $REMOTE_TOKENENV = 'GITHUB_TOKEN'; $REMOTE_MCP = 'github' }
  'gitlab' { $REMOTE_URL = 'https://gitlab.com'; $REMOTE_API = 'gitlab-api'; $REMOTE_TOKENENV = 'GITLAB_TOKEN'; $REMOTE_MCP = 'gitlab' }
  'gitlab-self' { $REMOTE_URL = Ask 'GitLab base URL' $REMOTE_URL; $REMOTE_API = 'gitlab-api'; $REMOTE_TOKENENV = 'GITLAB_TOKEN'; $REMOTE_MCP = 'gitlab' }
  'bitbucket' {
    $defUrl = if ($REMOTE_URL) { $REMOTE_URL } else { 'https://api.bitbucket.org/2.0' }
    $REMOTE_URL = Ask 'Bitbucket base URL' $defUrl
    $REMOTE_API = 'bitbucket'; $REMOTE_TOKENENV = 'BITBUCKET_TOKEN'; $REMOTE_MCP = 'bitbucket'
  }
  'forgejo' {
    $REMOTE_URL = Ask 'Forgejo base URL' $REMOTE_URL
    $REMOTE_API = 'gitea-api'
    if (-not $REMOTE_TOKENENV) { $REMOTE_TOKENENV = 'GIT_REMOTE_TOKEN' }
    $REMOTE_MCP = 'forgejo'
  }
  'gitea' {
    $REMOTE_URL = Ask 'Gitea base URL' $REMOTE_URL
    $REMOTE_API = 'gitea-api'
    if (-not $REMOTE_TOKENENV) { $REMOTE_TOKENENV = 'GIT_REMOTE_TOKEN' }
    $REMOTE_MCP = 'gitea'
  }
  'none' { $REMOTE_URL = ''; $REMOTE_API = ''; $REMOTE_TOKENENV = ''; $REMOTE_MCP = 'none' }
  default {
    $REMOTE_URL = Ask 'Base URL (e.g. https://git.example.com)' $REMOTE_URL
    $defApi = if ($REMOTE_API) { $REMOTE_API } else { 'generic' }
    $REMOTE_API = Ask 'API flavour (gitlab-api/github-api/bitbucket/gitea-api/generic)' $defApi
    $defTok = if ($REMOTE_TOKENENV) { $REMOTE_TOKENENV } else { 'GIT_REMOTE_TOKEN' }
    $REMOTE_TOKENENV = Ask 'Env var holding the token' $defTok
    $defMcp = if ($REMOTE_MCP) { $REMOTE_MCP } else { 'none' }
    $REMOTE_MCP = Ask 'Git-host MCP (github/gitlab/bitbucket/forgejo/gitea/none)' $defMcp
  }
}
if ($REMOTE_TYPE -ne 'none' -and $REMOTE_TYPE -ne 'custom') {
  $REMOTE_MCP = Ask 'Git-host MCP (github/gitlab/bitbucket/forgejo/gitea/none)' $REMOTE_MCP
}

# GitKraken (client MCP, independent of the remote host above)
$GITKRAKEN_ON = AskYn 'wire the GitKraken MCP (workspaces/PRs/issues via the gk CLI)?' (Dyn (J '.gitkraken.enabled'))

# dolt sync-on-close
$SYNC_ONCLOSE = J '.sync.askOnClose'
if (-not $SYNC_ONCLOSE) { $SYNC_ONCLOSE = 'true' }
if ($REMOTE_TYPE -eq 'none') { $SYNC_ONCLOSE = 'false' }
if ($REMOTE_TYPE -ne 'none') { $SYNC_ONCLOSE = AskYn 'ask to push + dolt-sync on each Beads issue close?' (Dyn $SYNC_ONCLOSE) }
$PSTART = J '.sync.pullOnStart'
if (-not $PSTART) { $PSTART = 'true' }
if ($REMOTE_TYPE -ne 'none') { $PSTART = AskYn 'auto-pull shared Beads issues at session start?' (Dyn $PSTART) }

# Ollama
$OLLAMA_ON = AskYn 'set up Ollama (local models)?' (Dyn (J '.ollama.enabled'))
$OLLAMA_URL = J '.ollama.url'
if (-not $OLLAMA_URL) { $OLLAMA_URL = 'http://localhost:11434' }
$ollamaJson = @()
if ($cfgObj -and $cfgObj.ollama -and $cfgObj.ollama.models) { $ollamaJson = @($cfgObj.ollama.models) }
if ($OLLAMA_ON -eq 'true') {
  $cur = ($ollamaJson -join ',')
  if (-not $cur) { $cur = 'qwen3-coder' }
  $OLLAMA_MODELS = Ask 'Ollama models (comma-separated; qwen3-coder recommended)' $cur
  $OLLAMA_URL = Ask 'Ollama URL' $OLLAMA_URL
  $ollamaJson = @($OLLAMA_MODELS -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 })
}
# router auto-on with ollama
$ROUTER_DEF = Dyn (J '.router.enabled')
if ($OLLAMA_ON -eq 'true') { $ROUTER_DEF = 'y' }
$ROUTER_ON = AskYn 'claude-code-router (route easy/background tasks to cheap/local models)?' $ROUTER_DEF

# team preferences
$TEAM_ON = AskYn 'shared team/user preferences (code style)?' (Dyn (J '.teamPrefs.enabled'))
$TEAM_STYLE = J '.teamPrefs.codeStyle'
if (-not $TEAM_STYLE) { $TEAM_STYLE = 'google' }
if ($TEAM_ON -eq 'true') { $TEAM_STYLE = Ask 'code style preset (google/airbnb/standard/custom)' $TEAM_STYLE }

$AIM = Ask 'project aim' (J '.project.aim')
$ARCH = Ask 'architecture' (J '.project.architecture')
$OS = Ask 'OS' (J '.dev.os')
$IDE = Ask 'IDE' (J '.dev.ide')

$GIT_MODEL = J '.git.model'
if (-not $GIT_MODEL) { $GIT_MODEL = 'none' }
$GIT_STRICT = 'false'; $GIT_PRONLY = 'false'; $GIT_AUTOREL = 'false'; $GIT_VER = 'none'; $GIT_TAGS = 'true'; $GIT_CHORE = 'false'
if ($VCS_SYS -eq 'git') {
  Write-Output "Git branching model:"
  $GIT_MODEL = Ask 'model (simple/gitflow/none)' $GIT_MODEL
  if ($GIT_MODEL -ne 'none' -and $GIT_MODEL) {
    $GIT_STRICT = AskYn 'strict branch rules?' (Dyn (J '.git.strict'))
    $GIT_PRONLY = AskYn 'merges only via PR (no direct push to main/develop)?' (Dyn (J '.git.prOnly'))
    $GIT_AUTOREL = AskYn 'auto-release on develop->main?' (Dyn (J '.git.autoRelease'))
    if ($GIT_AUTOREL -eq 'true') {
      $GIT_VER = Ask 'version strategy (semver/calver)' (J '.git.versionStrategy')
      $GIT_TAGS = AskYn 'git tag on release?' (Dyn (J '.git.releaseTags'))
    }
    $GIT_CHORE = AskYn 'allow chore/* branches?' (Dyn (J '.git.chore'))
  }
}

$cfgOut = [ordered]@{
  caveman = [ordered]@{ enabled = ($CAVE_ON -eq 'true'); mode = $CAVE_MODE }
  rtk = [ordered]@{ enabled = ($RTK_ON -eq 'true') }
  router = [ordered]@{ enabled = ($ROUTER_ON -eq 'true') }
  graphify = [ordered]@{ enabled = ($GRAPHIFY_ON -eq 'true') }
  taskmaster = [ordered]@{ enabled = ($TM_ON -eq 'true') }
  mcp = [ordered]@{ filesystem = ($FS_ON -eq 'true'); context7 = ($CTX7_ON -eq 'true'); cocoindex = ($COCO_ON -eq 'true') }
  memory = [ordered]@{ enabled = ($MEM_ON -eq 'true'); graph = ($MEM_GRAPH -eq 'true'); intensity = $MEM_INT }
  agents = [ordered]@{ claude = ($AGENT_CLAUDE -eq 'true'); copilot = ($AGENT_COPILOT -eq 'true'); codex = ($AGENT_CODEX -eq 'true') }
  modelRouting = [ordered]@{ enabled = ($MODELROUTING_ON -eq 'true') }
  codexsaver = [ordered]@{ enabled = ($CODEXSAVER_ON -eq 'true'); provider = $CODEXSAVER_PROVIDER; apiKeyEnv = $CODEXSAVER_KEYENV }
  claude = [ordered]@{ auth = $CLAUDE_AUTH }
  vcs = [ordered]@{ system = $VCS_SYS }
  remote = [ordered]@{ type = $REMOTE_TYPE; baseUrl = $REMOTE_URL; api = $REMOTE_API; tokenEnv = $REMOTE_TOKENENV; mcp = $REMOTE_MCP }
  gitkraken = [ordered]@{ enabled = ($GITKRAKEN_ON -eq 'true') }
  sync = [ordered]@{ askOnClose = ($SYNC_ONCLOSE -eq 'true'); pullOnStart = ($PSTART -eq 'true') }
  ollama = [ordered]@{ enabled = ($OLLAMA_ON -eq 'true'); url = $OLLAMA_URL; models = $ollamaJson }
  teamPrefs = [ordered]@{ enabled = ($TEAM_ON -eq 'true'); codeStyle = $TEAM_STYLE }
  project = [ordered]@{ aim = $AIM; architecture = $ARCH }
  dev = [ordered]@{ os = $OS; ide = $IDE }
  git = [ordered]@{ model = $GIT_MODEL; strict = ($GIT_STRICT -eq 'true'); prOnly = ($GIT_PRONLY -eq 'true'); autoRelease = ($GIT_AUTOREL -eq 'true'); versionStrategy = $GIT_VER; releaseTags = ($GIT_TAGS -eq 'true'); chore = ($GIT_CHORE -eq 'true') }
  templates_search = $false
}
Write-JsonFile $CFG $cfgOut
Write-Output "  updated $CFG"
& (Join-Path $AIFLOW_HOME 'lib/apply.ps1')
