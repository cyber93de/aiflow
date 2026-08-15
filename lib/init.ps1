# aiflow init - copy templates, ask a few questions, write .aiflow/config.json, apply.
# Everything is project-scoped. No global state, no tokens stored globally.
$ErrorActionPreference = 'Continue'

$AIFLOW_HOME = if ($env:AIFLOW_HOME) { $env:AIFLOW_HOME } else { Split-Path -Parent $PSScriptRoot }
$TPL = Join-Path $AIFLOW_HOME 'templates'

function Have($name) { [bool](Get-Command $name -ErrorAction SilentlyContinue) }

$Target = "."
$Force = $false
$NoGit = $false
$NoBeads = $false
$Yes = $false
$InstallDeps = 0
$NoTokenSave = $false
foreach ($a in $args) {
  switch ($a) {
    '--force' { $Force = $true }
    '--no-git' { $NoGit = $true }
    '--no-beads' { $NoBeads = $true }
    '--yes' { $Yes = $true }
    '-y' { $Yes = $true }
    '--install-deps' { $InstallDeps = 1 }
    '--no-install-deps' { $InstallDeps = -1 }
    '--no-token-saving' { $NoTokenSave = $true }
    default {
      if ($a -like '-*') { [Console]::Error.WriteLine("unknown flag: $a"); exit 2 }
      else { $Target = $a }
    }
  }
}
New-Item -ItemType Directory -Force -Path $Target | Out-Null
$Target = (Resolve-Path $Target).Path

# ---- detect new vs existing (brownfield) project BEFORE we add our files ----
$Existing = $false
$hasGitHead = $false
if (Test-Path (Join-Path $Target '.git')) {
  Push-Location $Target
  & git rev-parse --verify HEAD *> $null
  $hasGitHead = ($LASTEXITCODE -eq 0)
  Pop-Location
}
$otherEntries = @(Get-ChildItem -Path $Target -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne '.git' })
if ($hasGitHead -or $otherEntries.Count -gt 0) { $Existing = $true }
if ($Existing) {
  Write-Output ">> aiflow init -> $Target  (existing project: files preserved, onboarding offered)"
} else {
  Write-Output ">> aiflow init -> $Target  (new project)"
}

# ---- copy static templates (no clobber unless --force) ----
function Copy-TemplateTree($srcRoot, $destRoot, $force) {
  Get-ChildItem -Path $srcRoot -Force -ErrorAction SilentlyContinue | ForEach-Object {
    $destPath = Join-Path $destRoot $_.Name
    if ($_.PSIsContainer) {
      New-Item -ItemType Directory -Force -Path $destPath | Out-Null
      Copy-TemplateTree $_.FullName $destPath $force
    } elseif ($force -or -not (Test-Path $destPath)) {
      Copy-Item -Path $_.FullName -Destination $destPath -Force
    }
  }
}
Copy-TemplateTree $TPL $Target $Force
# no chmod +x equivalent needed on Windows - the exec bit is a POSIX concept.
Set-Location $Target

# ---- OS default: this .ps1 twin only ships in the windows archive - always windows ----
$OS_DEF = 'windows'

# ---- interactive helpers (ask_yn always emits true/false, also in --yes mode) ----
function Ask($prompt, $d) {
  if ($Yes) { return $d }
  $a = Read-Host "  $prompt [$d]"
  if ([string]::IsNullOrEmpty($a)) { return $d }
  return $a
}
function AskYn($prompt, $d) {
  if ($Yes) { $a = $d }
  else {
    $a = Read-Host "  $prompt (y/n) [$d]"
    if ([string]::IsNullOrEmpty($a)) { $a = $d }
  }
  if ($a -match '^[Yy]' -or $a -eq 'true') { return 'true' }
  return 'false'
}

Write-Output ""
Write-Output "Configure this project (Enter = default):"
if ($NoTokenSave) {
  Write-Output "  --no-token-saving: caveman + rtk are OFF (full, unfiltered output)."
  $CAVE_ON = 'false'; $CAVE_MODE = 'full'; $RTK_ON = 'false'
} else {
  Write-Output "  Token-saving defaults (caveman + rtk) and intensive graph-memory learning are ON by default."
  $CAVE_ON = AskYn 'Save tokens with caveman (terse output)?' 'y'
  $CAVE_MODE = 'full'
  if ($CAVE_ON -eq 'true') { $CAVE_MODE = Ask 'caveman mode (full recommended / lite / ultra)' 'full' }
  $RTK_ON = AskYn 'Save tokens by filtering CLI output with rtk?' 'y'
}
$PONYTAIL_ON = AskYn 'Use ponytail (YAGNI skill: reuse/simplify before writing new code)?' 'n'
$PONYTAIL_MODE = 'full'
if ($PONYTAIL_ON -eq 'true') { $PONYTAIL_MODE = Ask 'ponytail mode (full recommended / lite / ultra)' 'full' }
$GRAPHIFY_ON = AskYn 'Use graphify (structural code graph: imports/call-graph) for memory?' 'y'
$COCO_ON = AskYn 'Use cocoindex-code (semantic code RAG search, local, ~70% fewer tokens)?' 'y'
$TM_ON = AskYn 'Use claude-task-master for task decomposition?' 'y'
$FS_ON = AskYn 'Enable filesystem MCP?' 'y'
$CTX7_ON = AskYn 'Enable context7 MCP (live library docs)?' 'y'

# ---- Claude memory + graph-memory intensity ----
Write-Output ""
Write-Output "Claude memory (intensive graph-memory learning is recommended):"
$MEM_ON = AskYn 'Enable persistent Claude memory?' 'y'
$MEM_GRAPH = 'false'; $MEM_INT = 'off'
if ($MEM_ON -eq 'true') {
  $MEM_GRAPH = AskYn 'Learn the codebase into a knowledge graph (graph memory)?' 'y'
  $MEM_INT = Ask 'Memory learning intensity (aggressive / normal / light)' 'aggressive'
}

# ---- which coding agent(s) this project targets ----
Write-Output ""
Write-Output "Coding agent(s) - aiflow renders AGENTS.md + per-agent MCP config for whichever you pick:"
$AGENT_CLAUDE = AskYn 'Claude Code (subagents, hooks, slash-commands, Ralph loop - the full feature set)' 'y'
$AGENT_COPILOT = AskYn 'GitHub Copilot (AGENTS.md via .github/copilot-instructions.md + .vscode/mcp.json)' 'n'
$AGENT_CODEX = AskYn 'OpenAI Codex CLI (reads AGENTS.md directly + .codex/config.toml)' 'n'

# ---- model routing: cheap-model default for audit-only subagents (Claude Code only, on by default) ----
$MODELROUTING_ON = 'true'

# ---- CodexSaver: optional cost-aware MCP router for Codex CLI (needs a provider API key) ----
$CODEXSAVER_ON = 'false'; $CODEXSAVER_PROVIDER = 'deepseek'; $CODEXSAVER_KEYENV = 'DEEPSEEK_API_KEY'
if ($AGENT_CODEX -eq 'true') {
  Write-Output ""
  Write-Output "CodexSaver (https://github.com/fendouai/CodexSaver) routes cheap/bounded Codex work"
  Write-Output "(docs, tests, explanation) to a cheaper worker - needs Python + a provider API key."
  $CODEXSAVER_ON = AskYn 'Install CodexSaver for Codex CLI?' 'n'
  if ($CODEXSAVER_ON -eq 'true') {
    $CODEXSAVER_PROVIDER = Ask 'Provider (deepseek recommended)' 'deepseek'
    $CODEXSAVER_KEYENV = Ask 'Env var holding the provider API key' 'DEEPSEEK_API_KEY'
  }
}

# ---- Claude access: OAuth vs API key (token-based; no OAuth for Git hosts) ----
Write-Output ""
Write-Output "Claude access (token-based; pick how you authenticate):"
$CLAUDE_AUTH = Ask 'Claude auth (apikey = ANTHROPIC_API_KEY / oauth = claude setup-token)' 'apikey'

# ---- local version control: git / svn / none ----
Write-Output ""
Write-Output "Version control:"
$VCS_SYS = Ask 'Local version control (git / svn / none)' 'git'

# ---- remote host: token-based only (no OAuth) ----
Write-Output ""
Write-Output "Remote host (API tokens only - no OAuth):"
Write-Output "  github | github-enterprise | gitlab | gitlab-self | bitbucket | forgejo | gitea | custom | none"
$REMOTE_TYPE = Ask 'Remote type' 'github'
$REMOTE_URL = ''; $REMOTE_API = ''; $REMOTE_TOKENENV = ''; $REMOTE_MCP = ''
switch ($REMOTE_TYPE) {
  'github' { $REMOTE_URL = 'https://github.com'; $REMOTE_API = 'github-api'; $REMOTE_TOKENENV = 'GITHUB_TOKEN'; $REMOTE_MCP = 'github' }
  'github-enterprise' { $REMOTE_URL = Ask 'GHE base URL (e.g. https://github.example.com)' ''; $REMOTE_API = 'github-api'; $REMOTE_TOKENENV = 'GITHUB_TOKEN'; $REMOTE_MCP = 'github' }
  'gitlab' { $REMOTE_URL = 'https://gitlab.com'; $REMOTE_API = 'gitlab-api'; $REMOTE_TOKENENV = 'GITLAB_TOKEN'; $REMOTE_MCP = 'gitlab' }
  'gitlab-self' { $REMOTE_URL = Ask 'GitLab base URL (e.g. https://gitlab.example.com)' ''; $REMOTE_API = 'gitlab-api'; $REMOTE_TOKENENV = 'GITLAB_TOKEN'; $REMOTE_MCP = 'gitlab' }
  'bitbucket' { $REMOTE_URL = Ask 'Bitbucket base URL' 'https://api.bitbucket.org/2.0'; $REMOTE_API = 'bitbucket'; $REMOTE_TOKENENV = 'BITBUCKET_TOKEN'; $REMOTE_MCP = 'bitbucket' }
  'forgejo' { $REMOTE_URL = Ask 'Forgejo base URL (e.g. https://code.example.com)' ''; $REMOTE_API = 'gitea-api'; $REMOTE_TOKENENV = 'GIT_REMOTE_TOKEN'; $REMOTE_MCP = 'forgejo' }
  'gitea' { $REMOTE_URL = Ask 'Gitea base URL (e.g. https://git.example.com)' ''; $REMOTE_API = 'gitea-api'; $REMOTE_TOKENENV = 'GIT_REMOTE_TOKEN'; $REMOTE_MCP = 'gitea' }
  'none' { $REMOTE_URL = ''; $REMOTE_API = ''; $REMOTE_TOKENENV = ''; $REMOTE_MCP = 'none' }
  default {
    Write-Output "  Custom host - pick the matching API + MCP:"
    $REMOTE_URL = Ask 'Base URL (e.g. https://git.example.com)' ''
    $REMOTE_API = Ask 'API flavour (gitlab-api / github-api / bitbucket / gitea-api / generic)' 'generic'
    $REMOTE_TOKENENV = Ask 'Env var holding the token' 'GIT_REMOTE_TOKEN'
    $REMOTE_MCP = Ask 'Git-host MCP to wire (github / gitlab / bitbucket / forgejo / gitea / none)' 'none'
  }
}
# offer to override the auto-picked MCP (so the list is always available)
if ($REMOTE_TYPE -ne 'none' -and $REMOTE_TYPE -ne 'custom') {
  $REMOTE_MCP = Ask 'Git-host MCP to wire (github/gitlab/bitbucket/forgejo/gitea/none)' $REMOTE_MCP
}

# ---- GitKraken (client MCP, independent of the remote host above) ----
Write-Output ""
Write-Output "GitKraken is a git client, not a host - wire its MCP alongside whichever host you picked above."
$GITKRAKEN_ON = AskYn 'Also wire the GitKraken MCP (workspaces/PRs/issues via the gk CLI)?' 'n'

# ---- dolt sync-on-close rule ----
$SYNC_ONCLOSE = 'true'
if ($REMOTE_TYPE -eq 'none') { $SYNC_ONCLOSE = 'false' }
if ($REMOTE_TYPE -ne 'none') { $SYNC_ONCLOSE = AskYn 'Ask to push + dolt-sync the remote each time a Beads issue is closed?' 'y' }

# ---- Ollama (local models, no key) ----
Write-Output ""
Write-Output "Ollama (local models - no API key needed):"
$OLLAMA_ON = AskYn 'Set up Ollama for local models?' 'n'
$OLLAMA_URL = 'http://localhost:11434'; $OLLAMA_MODELS = ''
if ($OLLAMA_ON -eq 'true') {
  Write-Output "  Suggested: qwen3-coder (recommended, newest Qwen), qwen3, llama3.1, deepseek-r1, gemma2, mistral"
  $OLLAMA_MODELS = Ask 'Models to install (comma-separated)' 'qwen3-coder'
  $OLLAMA_URL = Ask 'Ollama URL' $OLLAMA_URL
}
# router auto-on when Ollama is set up (so the local models actually get used)
$routerDefault = if ($OLLAMA_ON -eq 'true') { 'y' } else { 'n' }
$ROUTER_ON = AskYn 'Use claude-code-router (route easy/background tasks to cheap/local models)?' $routerDefault

# ---- team/user-wide preferences (shared, versioned) ----
Write-Output ""
Write-Output "Shared team preferences (versioned in .aiflow/team-prefs.json):"
$TEAM_ON = AskYn 'Use shared team/user preferences (code style, language)?' 'n'
$TEAM_STYLE = 'google'
if ($TEAM_ON -eq 'true') { $TEAM_STYLE = Ask 'Code style preset (google / airbnb / standard / custom)' 'google' }

$AIM = Ask 'Project aim (what should it achieve?)' ''
$ARCH = Ask 'Target architecture (e.g. hexagonal, MVC, layered...)' ''
$OS = Ask 'Your OS (windows / macos / linux)' $OS_DEF
$IDE = Ask 'Your IDE (vscode / intellij / other)' 'vscode'
$TPL_SEARCH = AskYn 'Browse claude-code-templates for extra configs now?' 'n'

# ---- git branching governance (only when local VCS is git) ----
$GIT_MODEL = 'none'; $GIT_STRICT = 'false'; $GIT_PRONLY = 'false'; $GIT_AUTOREL = 'false'
$GIT_VER = 'none'; $GIT_TAGS = 'true'; $GIT_CHORE = 'false'
if ($VCS_SYS -eq 'git') {
  Write-Output ""
  Write-Output "Git branching model:"
  $GIT_MODEL = Ask 'Branching model (simple / gitflow / none)' 'simple'
  if ($GIT_MODEL -ne 'none') {
    $GIT_STRICT = AskYn 'Enable strict branch rules?' 'y'
    $GIT_PRONLY = AskYn 'Merges only via Pull Requests (no direct push to main/develop)?' 'y'
    $GIT_AUTOREL = AskYn 'Auto-create a release when develop merges into main?' 'n'
    if ($GIT_AUTOREL -eq 'true') {
      $GIT_VER = Ask 'Version strategy (semver / calver)' 'semver'
      $GIT_TAGS = AskYn 'Create a git tag on each release?' 'y'
    }
    $GIT_CHORE = AskYn 'Allow chore/* branches?' 'y'
  }
}

# ---- write .aiflow/config.json ----
New-Item -ItemType Directory -Force -Path '.aiflow' | Out-Null
$ollamaJson = @($OLLAMA_MODELS -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 })
$verFile = Join-Path $AIFLOW_HOME 'VERSION'
$aiflowVersion = if (Test-Path $verFile) { (Get-Content $verFile -TotalCount 1).Trim() } else { '0.0.0' }

function Write-JsonFile($path, $obj) {
  $json = $obj | ConvertTo-Json -Depth 20
  $full = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $path))
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($full, $json, $utf8NoBom)
}

$cfgOut = [ordered]@{
  caveman = [ordered]@{ enabled = ($CAVE_ON -eq 'true'); mode = $CAVE_MODE }
  rtk = [ordered]@{ enabled = ($RTK_ON -eq 'true') }
  ponytail = [ordered]@{ enabled = ($PONYTAIL_ON -eq 'true'); mode = $PONYTAIL_MODE }
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
  sync = [ordered]@{ askOnClose = ($SYNC_ONCLOSE -eq 'true'); pullOnStart = $true }
  ollama = [ordered]@{ enabled = ($OLLAMA_ON -eq 'true'); url = $OLLAMA_URL; models = $ollamaJson }
  teamPrefs = [ordered]@{ enabled = ($TEAM_ON -eq 'true'); codeStyle = $TEAM_STYLE }
  project = [ordered]@{ aim = $AIM; architecture = $ARCH }
  dev = [ordered]@{ os = $OS; ide = $IDE }
  git = [ordered]@{ model = $GIT_MODEL; strict = ($GIT_STRICT -eq 'true'); prOnly = ($GIT_PRONLY -eq 'true'); autoRelease = ($GIT_AUTOREL -eq 'true'); versionStrategy = $GIT_VER; releaseTags = ($GIT_TAGS -eq 'true'); chore = ($GIT_CHORE -eq 'true') }
  templates_search = ($TPL_SEARCH -eq 'true')
  meta = [ordered]@{ aiflowVersion = $aiflowVersion }
}
Write-JsonFile '.aiflow/config.json' $cfgOut
Write-Output "  wrote .aiflow/config.json"

# ---- .env ----
if (-not (Test-Path '.env')) {
  if (Test-Path '.env.example') {
    Copy-Item -Path '.env.example' -Destination '.env' -Force
    Write-Output "  .env created (fill in tokens!)"
  }
}

# ---- local version control ----
switch ($VCS_SYS) {
  'git' {
    if (-not $NoGit -and -not (Test-Path '.git')) {
      & git init -q
      if ($LASTEXITCODE -eq 0) { Write-Output "  git initialised" }
    }
  }
  'svn' {
    if (Have svn) {
      if (-not (Test-Path '.svn')) { Write-Output "  svn selected - run 'svnadmin create' / 'svn checkout' for your repo (aiflow won't auto-create it)" }
    } else {
      Write-Output "  ! svn selected but 'svn' not installed"
    }
  }
  'none' { Write-Output "  version control: none (git init / hooks / branching governance skipped)" }
}

# ---- beads ----
if (-not $NoBeads) {
  if (Have bd) {
    if (-not (Test-Path '.beads')) {
      & bd init *> $null
      Write-Output "  beads initialised"
    }
  } else {
    Write-Output "  ! 'bd' not found - install Beads or /beads:init in Claude later"
  }
}

# ---- render everything from config ----
& (Join-Path $AIFLOW_HOME 'lib/apply.ps1')

# ---- install missing tools (so you don't pre-install anything) ----
$DoDeps = $false
if ($InstallDeps -eq 1) { $DoDeps = $true }
elseif ($InstallDeps -eq -1) { $DoDeps = $false }
elseif (-not $Yes) {
  if ((AskYn 'Install the enabled tools now (claude, beads, + chosen extras)?' 'y') -eq 'true') { $DoDeps = $true }
}
if ($DoDeps) {
  $depsArgs = @()
  if ($Yes) { $depsArgs = @('--yes') }
  & (Join-Path $AIFLOW_HOME 'lib/install-deps.ps1') @depsArgs
}

# ---- graphify build (automated) ----
if ($GRAPHIFY_ON -eq 'true' -and (Have graphify)) {
  Write-Output "  building graphify knowledge graph..."
  & graphify build . *> $null
  if ($LASTEXITCODE -ne 0) {
    & graphify . *> $null
    if ($LASTEXITCODE -ne 0) { Write-Output "    (run 'aiflow index' inside Claude with /graphify . )" }
  }
}

# ---- cocoindex-code RAG index (build so semantic search is ready) ----
if ($COCO_ON -eq 'true' -and (Have ccc)) {
  Write-Output "  building cocoindex-code RAG index..."
  & ccc index *> $null
  if ($LASTEXITCODE -ne 0) { Write-Output "    (run 'aiflow index' later to build the RAG index)" }
}

# ---- Ollama models (pull selected models so they're ready to use) ----
if ($OLLAMA_ON -eq 'true') {
  & (Join-Path $AIFLOW_HOME 'lib/ollama.ps1') pull
  if ($LASTEXITCODE -ne 0) { Write-Output "  (run 'aiflow ollama pull' later to fetch models)" }
}

# ---- optional: browse claude-code-templates ----
if ($TPL_SEARCH -eq 'true') {
  Write-Output "  launching claude-code-templates browser..."
  & npx -y claude-code-templates@latest
}

# ---- existing project: offer to learn the codebase into memory ----
function Import-DotEnvLocal {
  if (Test-Path '.env') {
    Get-Content '.env' | ForEach-Object {
      if ($_ -match '^\s*#') { return }
      if ($_ -match '^\s*([^=]+?)\s*=\s*(.*)$') {
        $name = $matches[1].Trim(); $val = $matches[2].Trim().Trim('"')
        if ($name) { [Environment]::SetEnvironmentVariable($name, $val, 'Process') }
      }
    }
  }
}
$DidOnboard = $false
if ($Existing -and (Have claude)) {
  if (-not $Yes -and (AskYn 'Existing codebase detected - learn it now into memory + AGENTS.md + arc42 (aiflow onboard)?' 'y') -eq 'true') {
    Import-DotEnvLocal
    & (Join-Path (Get-Location) '.aiflow/run-agent.ps1') onboarder
    if ($LASTEXITCODE -eq 0) { $DidOnboard = $true } else { Write-Output "  (run 'aiflow onboard' later)" }
  }
}

Write-Output ""
Write-Output "Done."
if ($Existing) {
  Write-Output "This is an EXISTING project. Your files were preserved (no overwrite without --force)."
  Write-Output "Next steps:"
  Write-Output "  1) edit .env        -> GITHUB_TOKEN + (ANTHROPIC_API_KEY or CLAUDE_CODE_OAUTH_TOKEN)"
  $step2 = if ($DidOnboard) { 'review what onboard learned:' } else { 'learn the codebase:  aiflow onboard   ->' }
  Write-Output "  2) $step2 .claude/memory/codebase-map.md + AGENTS.md section 1/2 + docs/architecture/"
  Write-Output "  3) reconcile AGENTS.md / docs/architecture with reality, then: aiflow shell (Claude), or open Copilot/Codex CLI"
  Write-Output "  4) optional baseline audits: aiflow security-check | quality-check | dependency-check | test-gap | docs-check"
  if ($DidOnboard) { Write-Output "  -> run /compact now: what onboard learned is persisted in memory + AGENTS.md + arc42, the transcript isn't needed" }
} else {
  Write-Output "This is a NEW project. Next steps:"
  Write-Output "  1) edit .env        -> GITHUB_TOKEN + (ANTHROPIC_API_KEY or CLAUDE_CODE_OAUTH_TOKEN)"
  Write-Output "  2) review AGENTS.md + .claude/memory/project-aim.md (fill the [EDIT ME] blocks)"
  Write-Output "  3) aiflow shell     -> start Claude Code (secrets loaded), or open Copilot/Codex CLI directly"
  Write-Output "  4) in the session: run /compact right after this - the aim, stack and architecture from the Q&A"
  Write-Output "     are already in .aiflow/config.json + .claude/memory/, so the setup transcript is dead weight"
}
Write-Output "  Change any choice later: aiflow change-settings   |   full manual: README.md / README.de.md"
