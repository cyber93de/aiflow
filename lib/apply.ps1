# aiflow apply - render project files from .aiflow/config.json (idempotent).
# Called by `aiflow init` and `aiflow change-settings`. Never stores anything global.
$ErrorActionPreference = 'Continue'

$AIFLOW_HOME = if ($env:AIFLOW_HOME) { $env:AIFLOW_HOME } else { Split-Path -Parent $PSScriptRoot }
$CFG = ".aiflow/config.json"
if (-not (Test-Path $CFG)) { [Console]::Error.WriteLine("no $CFG - run 'aiflow init' first"); exit 1 }

$cfgObj = $null
try { $cfgObj = Get-Content $CFG -Raw | ConvertFrom-Json } catch { $cfgObj = $null }
if (-not $cfgObj) { [Console]::Error.WriteLine("$CFG could not be parsed"); exit 1 }

function Have($name) { [bool](Get-Command $name -ErrorAction SilentlyContinue) }

# Null-check only (NOT jq's `//` semantics): an explicitly-set `false` must survive the
# default instead of being collapsed to it (aiflow-5qe - lib/apply.sh fixed the same way).
function Get-JVal($obj, $path, $default) {
  $cur = $obj
  foreach ($seg in $path -split '\.') {
    if ($null -eq $cur) { break }
    $cur = $cur.$seg
  }
  if ($null -eq $cur) { return $default }
  return $cur
}

function Write-JsonFile($path, $obj) {
  $json = $obj | ConvertTo-Json -Depth 20
  $full = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $path))
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($full, $json, $utf8NoBom)
}
function Write-PlainFile($path, $content) {
  $full = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $path))
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($full, $content, $utf8NoBom)
}
function Set-JsonProperty($obj, $name, $value) {
  if ($obj.PSObject.Properties.Match($name).Count -gt 0) { $obj.$name = $value }
  else { $obj | Add-Member -NotePropertyName $name -NotePropertyValue $value }
}
function ConvertTo-JsonCompact($val) { return (ConvertTo-Json -InputObject $val -Compress -Depth 10) }

$PROJ_DIR = (Get-Location).Path
# which coding agent(s) this project targets (default: claude only, for back-compat)
$AGENT_CLAUDE = [bool](Get-JVal $cfgObj 'agents.claude' $true)
$AGENT_COPILOT = [bool](Get-JVal $cfgObj 'agents.copilot' $false)
$AGENT_CODEX = [bool](Get-JVal $cfgObj 'agents.codex' $false)
# model routing: cheap-model default for audit-only subagents (Claude Code only)
$MODELROUTING_ON = [bool](Get-JVal $cfgObj 'modelRouting.enabled' $true)
$CODEXSAVER_ON = [bool](Get-JVal $cfgObj 'codexsaver.enabled' $false)
$CAVEMAN_ON = [bool](Get-JVal $cfgObj 'caveman.enabled' $false)
$CAVEMAN_MODE = Get-JVal $cfgObj 'caveman.mode' ''
$RTK_ON = [bool](Get-JVal $cfgObj 'rtk.enabled' $false)
$PONYTAIL_ON = [bool](Get-JVal $cfgObj 'ponytail.enabled' $false)
$PONYTAIL_MODE = Get-JVal $cfgObj 'ponytail.mode' 'full'
$ROUTER_ON = [bool](Get-JVal $cfgObj 'router.enabled' $false)
$GRAPHIFY_ON = [bool](Get-JVal $cfgObj 'graphify.enabled' $false)
$TASKMASTER_ON = [bool](Get-JVal $cfgObj 'taskmaster.enabled' $false)
$FS_ON = [bool](Get-JVal $cfgObj 'mcp.filesystem' $false)
$CTX7_ON = [bool](Get-JVal $cfgObj 'mcp.context7' $false)
$COCO_ON = [bool](Get-JVal $cfgObj 'mcp.cocoindex' $false)
$MEMORY_ON = [bool](Get-JVal $cfgObj 'memory.enabled' $false)
$MEMORY_GRAPH = [bool](Get-JVal $cfgObj 'memory.graph' $false)
$MEMORY_INT = Get-JVal $cfgObj 'memory.intensity' 'normal'
$CLAUDE_AUTH = Get-JVal $cfgObj 'claude.auth' 'apikey'
# local version control (git/svn/none)
$VCS_SYS = Get-JVal $cfgObj 'vcs.system' 'git'
# remote host: new schema (.remote.*) with fallback to legacy string .vcs
$REMOTE_TYPE = Get-JVal $cfgObj 'remote.type' ''
if (-not $REMOTE_TYPE) {
  if ($cfgObj.PSObject.Properties.Match('vcs').Count -gt 0 -and $cfgObj.vcs -is [string]) { $REMOTE_TYPE = $cfgObj.vcs }
}
if (-not $REMOTE_TYPE) { $REMOTE_TYPE = 'github' }
$REMOTE_URL = Get-JVal $cfgObj 'remote.baseUrl' ''
$REMOTE_API = Get-JVal $cfgObj 'remote.api' ''
$REMOTE_TOKENENV = Get-JVal $cfgObj 'remote.tokenEnv' 'GITHUB_TOKEN'
$REMOTE_MCP = Get-JVal $cfgObj 'remote.mcp' ''
$GITKRAKEN_ON = [bool](Get-JVal $cfgObj 'gitkraken.enabled' $false)
# derive the git-host MCP from the remote type when not explicitly set
if (-not $REMOTE_MCP) {
  $REMOTE_MCP = switch ($REMOTE_TYPE) {
    { $_ -in 'github', 'github-enterprise' } { 'github' }
    { $_ -in 'gitlab', 'gitlab-self' } { 'gitlab' }
    'bitbucket' { 'bitbucket' }
    'forgejo' { 'forgejo' }
    'gitea' { 'gitea' }
    default { 'none' }
  }
}
$SYNC_ONCLOSE = [bool](Get-JVal $cfgObj 'sync.askOnClose' $false)
$OLLAMA_ON = [bool](Get-JVal $cfgObj 'ollama.enabled' $false)
$OLLAMA_URL = Get-JVal $cfgObj 'ollama.url' 'http://localhost:11434'
$TEAM_ON = [bool](Get-JVal $cfgObj 'teamPrefs.enabled' $false)
$TEAM_STYLE = Get-JVal $cfgObj 'teamPrefs.codeStyle' ''
$AIM = Get-JVal $cfgObj 'project.aim' ''
$ARCH = Get-JVal $cfgObj 'project.architecture' ''
$OS = Get-JVal $cfgObj 'dev.os' ''
$IDE = Get-JVal $cfgObj 'dev.ide' ''

# ---------- .mcp.json (only enabled servers) ----------
$mcpServers = [ordered]@{}
function Add-Mcp($name, $obj) { $mcpServers[$name] = $obj }
function Get-EnvRef($name) { return '${' + $name + '}' }   # literal ${VAR} for .env expansion
function Get-HostOnly($url) { return ($url -replace '^https?://', '' -replace '/.*$', '') }

# ---- git-host MCP (chosen by remote.mcp; token from remote.tokenEnv) ----
# Each host has its own MCP server. Self-hosted variants get their base URL wired in
# (GITHUB_HOST / GITLAB_API_URL / GITEA_URL) so enterprise/self-managed installs work.
switch ($REMOTE_MCP) {
  'github' {
    if ([string]::IsNullOrEmpty($REMOTE_URL) -or $REMOTE_URL -match '(?i)github\.com') {
      Add-Mcp 'github' ([ordered]@{
          command = 'docker'
          args    = @('run', '-i', '--rm', '-e', 'GITHUB_PERSONAL_ACCESS_TOKEN', 'ghcr.io/github/github-mcp-server')
          env     = [ordered]@{ GITHUB_PERSONAL_ACCESS_TOKEN = (Get-EnvRef $REMOTE_TOKENENV) }
        })
    } else {
      Add-Mcp 'github' ([ordered]@{
          command = 'docker'
          args    = @('run', '-i', '--rm', '-e', 'GITHUB_PERSONAL_ACCESS_TOKEN', '-e', 'GITHUB_HOST', 'ghcr.io/github/github-mcp-server')
          env     = [ordered]@{ GITHUB_PERSONAL_ACCESS_TOKEN = (Get-EnvRef $REMOTE_TOKENENV); GITHUB_HOST = (Get-HostOnly $REMOTE_URL) }
        })
    }
  }
  'gitlab' {
    $gurl = if ($REMOTE_URL) { $REMOTE_URL } else { 'https://gitlab.com' }
    Add-Mcp 'gitlab' ([ordered]@{
        command = 'npx'; args = @('-y', '@modelcontextprotocol/server-gitlab')
        env     = [ordered]@{ GITLAB_PERSONAL_ACCESS_TOKEN = (Get-EnvRef $REMOTE_TOKENENV); GITLAB_API_URL = "$gurl/api/v4" }
      })
  }
  'bitbucket' {
    Add-Mcp 'bitbucket' ([ordered]@{
        command = 'npx'; args = @('-y', '@aashari/mcp-server-atlassian-bitbucket')
        env     = [ordered]@{ ATLASSIAN_BITBUCKET_ACCESS_TOKEN = (Get-EnvRef $REMOTE_TOKENENV); BITBUCKET_BASE_URL = $REMOTE_URL }
      })
  }
  { $_ -eq 'forgejo' -or $_ -eq 'gitea' } {
    Add-Mcp $REMOTE_MCP ([ordered]@{
        command = 'npx'; args = @('-y', 'gitea-mcp-server')
        env     = [ordered]@{ GITEA_URL = $REMOTE_URL; GITEA_ACCESS_TOKEN = (Get-EnvRef $REMOTE_TOKENENV) }
      })
  }
  default { }   # none / custom/generic host with no known MCP - use CLI/REST instead
}
# GitKraken (git client, not a host - wired alongside whichever host MCP above, or alone)
if ($GITKRAKEN_ON) { Add-Mcp 'gitkraken' ([ordered]@{ command = 'gk'; args = @('mcp') }) }
# Filesystem
if ($FS_ON) { Add-Mcp 'filesystem' ([ordered]@{ command = 'npx'; args = @('-y', '@modelcontextprotocol/server-filesystem', $PROJ_DIR) }) }
# graphify (structural code graph: imports / call-graph / relationships)
if ($GRAPHIFY_ON) { Add-Mcp 'graphify' ([ordered]@{ command = 'python'; args = @('-m', 'graphify.serve', 'graphify-out/graph.json') }) }
# cocoindex-code (semantic RAG code search: AST chunks + local embeddings, no key, incremental)
if ($COCO_ON) { Add-Mcp 'cocoindex-code' ([ordered]@{ command = 'ccc'; args = @('mcp') }) }
# task-master (task decomposition; claude-code provider needs no key)
if ($TASKMASTER_ON) { Add-Mcp 'task-master' ([ordered]@{ command = 'npx'; args = @('-y', 'task-master-ai'); env = [ordered]@{ MODEL = 'claude-code/sonnet' } }) }
# context7 (live library docs). CONTEXT7_API_KEY optional (higher rate limits); works keyless.
if ($CTX7_ON) { Add-Mcp 'context7' ([ordered]@{ command = 'npx'; args = @('-y', '@upstash/context7-mcp'); env = [ordered]@{ CONTEXT7_API_KEY = '${CONTEXT7_API_KEY}' } }) }

# same server set, rendered per agent (each coding agent has its own MCP config format/location)
if ($AGENT_CLAUDE) {
  $mcpOut = [ordered]@{}
  $mcpOut['mcpServers'] = $mcpServers
  $mcpOut['$comment'] = 'Generated by aiflow from .aiflow/config.json. Edit via: aiflow change-settings. Tokens come from .env (gitignored).'
  Write-JsonFile '.mcp.json' $mcpOut
  Write-Output "  .mcp.json rendered for Claude Code (host-mcp=$REMOTE_MCP gitkraken=$($GITKRAKEN_ON.ToString().ToLower()) filesystem=$($FS_ON.ToString().ToLower()) context7=$($CTX7_ON.ToString().ToLower()) graphify=$($GRAPHIFY_ON.ToString().ToLower()) cocoindex=$($COCO_ON.ToString().ToLower()) task-master=$($TASKMASTER_ON.ToString().ToLower()))"
}
if ($AGENT_CODEX) {
  New-Item -ItemType Directory -Force -Path '.codex' | Out-Null
  $codexLines = New-Object System.Collections.Generic.List[string]
  $codexLines.Add('# Generated by aiflow from .aiflow/config.json. Edit via: aiflow change-settings.')
  $codexLines.Add('# Codex CLI reads MCP servers from ~/.codex/config.toml (global) as of most releases -')
  $codexLines.Add("# this project-local copy may need merging there if your Codex version doesn't pick up")
  $codexLines.Add('# a repo-level config.toml. ${VAR} values below are aiflow''s .env convention (like')
  $codexLines.Add("# .mcp.json) - verify your Codex CLI version actually expands them from the environment;")
  $codexLines.Add("# if not, replace with the literal token or check Codex's own env-passthrough option.")
  foreach ($key in $mcpServers.Keys) {
    $entry = $mcpServers[$key]
    $codexLines.Add("[mcp_servers.$key]")
    $codexLines.Add("command = $(ConvertTo-JsonCompact $entry.command)")
    $codexLines.Add("args = $(ConvertTo-JsonCompact $entry.args)")
    if ($entry.Contains('env')) {
      $codexLines.Add("[mcp_servers.$key.env]")
      foreach ($ek in $entry['env'].Keys) {
        $codexLines.Add("$ek = $(ConvertTo-JsonCompact $entry['env'][$ek])")
      }
    }
    $codexLines.Add('')
  }
  if ($CODEXSAVER_ON) {
    # CodexSaver (https://github.com/fendouai/CodexSaver) has its own installer that normally
    # writes this same file - we own it instead and just point at the stable script path its
    # installer creates (~/.codexsaver/codexsaver_mcp.py), so re-running 'aiflow apply' never
    # clobbers/duplicates its entry. Codex CLI is a native binary; on this Windows-only .ps1
    # twin $HOME is already a native Windows path, so (unlike the bash twin, which needs
    # cygpath to convert Git-Bash's POSIX-style $HOME) no path conversion is needed here.
    $csPath = Join-Path $HOME '.codexsaver/codexsaver_mcp.py'
    $codexLines.Add('[mcp_servers.codexsaver]')
    $codexLines.Add('command = "python"')
    $codexLines.Add("args = $(ConvertTo-JsonCompact @($csPath))")
    $codexLines.Add('startup_timeout_sec = 10')
    $codexLines.Add('tool_timeout_sec = 120')
  }
  Write-PlainFile '.codex/config.toml' (($codexLines -join "`n") + "`n")
  Write-Output "  .codex/config.toml rendered for Codex CLI (codexsaver=$($CODEXSAVER_ON.ToString().ToLower()))"
}
if ($AGENT_COPILOT) {
  New-Item -ItemType Directory -Force -Path '.vscode' | Out-Null
  $vscodeOut = [ordered]@{
    '$comment' = 'Generated by aiflow from .aiflow/config.json. Edit via: aiflow change-settings. VS Code MCP schema - verify against current VS Code docs if servers don''t load. ${VAR} env values are aiflow''s .env convention - VS Code may need its own ${env:VAR} form instead; check VS Code MCP docs for the exact syntax your version supports.'
    servers    = $mcpServers
  }
  Write-JsonFile '.vscode/mcp.json' $vscodeOut
  Write-Output "  .vscode/mcp.json rendered for GitHub Copilot (VS Code)"
}

# ---------- model routing: stamp/strip 'model: haiku' on the 5 audit-only subagents ----------
# (Claude Code only - Copilot/Codex have no subagent concept). Only these 5 files ever get
# touched; every other .claude/agents/*.md stays byte-identical regardless of the toggle.
if ($AGENT_CLAUDE) {
  function Set-ModelRoutingLine([string]$path, [string]$mode) {
    if (-not (Test-Path $path)) { return }
    # [System.IO.File] resolves relative paths against [Environment]::CurrentDirectory, which
    # PowerShell does NOT keep in sync with Set-Location/Get-Location - a raw relative path here
    # can silently read/write the wrong file. Resolve through Get-Location first (same pattern
    # Write-JsonFile already uses above).
    $full = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $path))
    $raw = [System.IO.File]::ReadAllText($full)
    # templates/.claude/agents/*.md check out CRLF on Windows (no .gitattributes override) -
    # match the file's own line ending so we only ever touch the model: line, nothing else.
    $crlf = $raw.Contains("`r`n")
    $eol = if ($crlf) { "`r`n" } else { "`n" }
    $hadTrailingNewline = $raw.EndsWith("`n") -or $raw.EndsWith("`r")
    $lines = [System.Collections.Generic.List[string]]($raw -split "`r`n|`n|`r")
    if ($hadTrailingNewline -and $lines.Count -gt 0 -and $lines[$lines.Count - 1] -ceq '') {
      $lines.RemoveAt($lines.Count - 1)
    }
    $out = New-Object System.Collections.Generic.List[string]
    $infm = $false; $done = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
      $line = $lines[$i]
      if ($i -eq 0 -and $line -ceq '---') { $infm = $true; $out.Add($line); continue }
      if ($infm -and $line -ceq '---') {
        if ($mode -eq 'add' -and -not $done) { $out.Add('model: haiku'); $done = $true }
        $infm = $false; $out.Add($line); continue
      }
      if ($infm -and $line -cmatch '^model:[ \t]') {
        if ($mode -eq 'add' -and -not $done) { $out.Add('model: haiku'); $done = $true }
        continue
      }
      $out.Add($line)
    }
    $newText = ($out -join $eol) + $(if ($hadTrailingNewline) { $eol } else { '' })
    [System.IO.File]::WriteAllText($full, $newText, (New-Object System.Text.UTF8Encoding($false)))
  }
  $mrMode = if ($MODELROUTING_ON) { 'add' } else { 'strip' }
  foreach ($n in @('docs-sync', 'test-gap-advisor', 'dependency-auditor', 'performance-advisor', 'onboarder')) {
    Set-ModelRoutingLine (Join-Path '.claude/agents' "$n.md") $mrMode
  }
  Write-Output "  model routing: 5 audit subagents -> $(if ($MODELROUTING_ON) { 'haiku' } else { 'session default' })"
}

# ---------- ponytail (YAGNI skill): self-gates via .aiflow/config.json, nothing to render here ----------
Write-Output "  ponytail: $(if ($PONYTAIL_ON) { "on (mode=$PONYTAIL_MODE)" } else { 'off' })"

# ---------- release workflow (host-specific, tag-triggered; never overwrites an existing one) ----------
# Publishes a release entry/note on the host whenever a version tag is pushed. Doesn't bump
# versions - that stays local/manual (aiflow release --yes). One template per host in
# release-workflows/ (kept out of templates/ so it's never blindly copied for the wrong host).
$RWF_SRC = ''; $RWF_DEST = ''
switch ($REMOTE_TYPE) {
  { $_ -in 'github', 'github-enterprise' } { $RWF_SRC = 'github.yml'; $RWF_DEST = '.github/workflows/release.yml' }
  { $_ -in 'gitlab', 'gitlab-self' } { $RWF_SRC = 'gitlab.yml'; $RWF_DEST = '.gitlab-ci.yml' }
  'gitea' { $RWF_SRC = 'gitea.yml'; $RWF_DEST = '.gitea/workflows/release.yml' }
  'forgejo' { $RWF_SRC = 'forgejo.yml'; $RWF_DEST = '.forgejo/workflows/release.yml' }
  'bitbucket' { $RWF_SRC = 'bitbucket.yml'; $RWF_DEST = 'bitbucket-pipelines.yml' }
  default { }   # custom/none/gitkraken (client, not a host) - no predefined workflow
}
if ($RWF_SRC) {
  $rwfHome = Join-Path $AIFLOW_HOME "release-workflows/$RWF_SRC"
  if ((Test-Path $rwfHome) -and -not (Test-Path $RWF_DEST)) {
    $destDir = Split-Path -Parent $RWF_DEST
    if ($destDir) { New-Item -ItemType Directory -Force -Path $destDir | Out-Null }
    Copy-Item -Path $rwfHome -Destination $RWF_DEST -Force
    Write-Output "  release workflow: wrote $RWF_DEST (from $RWF_SRC)"
  }
}

# ---------- git branching governance + hooks (only when local VCS is git) ----------
if ($VCS_SYS -eq 'git') {
  try { & (Join-Path $AIFLOW_HOME 'lib/branching.ps1') } catch {}

  # git hooks (enforce conventional commits + lint/test).
  # Beads also installs git hooks (.beads/hooks) for JSONL sync. A repo can have only one
  # core.hooksPath, so when Beads is present we merge our enforcement INTO .beads/hooks (the
  # superset = beads sync + our checks) and point there. Otherwise we use .githooks. These
  # hook scripts have no .ps1 twin - git invokes them via its own bundled Git-for-Windows bash
  # through their shebang line regardless of host OS, so no chmod +x equivalent is needed either.
  if (Test-Path '.git') {
    if (Test-Path '.beads/hooks') {
      foreach ($h in @('pre-commit', 'commit-msg', 'pre-push')) {
        $hookSrc = Join-Path '.githooks' $h
        if (Test-Path $hookSrc) { Copy-Item -Path $hookSrc -Destination '.beads/hooks/' -Force }
      }
      & git config core.hooksPath .beads/hooks
      Write-Output "  git hooks enforced (core.hooksPath=.beads/hooks; merged with Beads sync)"
    } else {
      & git config core.hooksPath .githooks
      Write-Output "  git hooks enforced (core.hooksPath=.githooks)"
    }
  }
} else {
  Write-Output "  git branching/hooks skipped (vcs.system=$VCS_SYS)"
}

# ---------- Beads <-> remote issue sync config ----------
# Beads has its OWN host integration (`bd github` / `bd gitlab`), separate from the MCP server.
# Without owner/repo set, host sync never runs and issues stay local-only.
# We derive owner/repo from the git remote (non-secret; token stays in .env).
if (($REMOTE_TYPE -eq 'github' -or $REMOTE_TYPE -eq 'gitlab') -and (Test-Path '.beads') -and (Have bd)) {
  $gitRemoteUrl = & git remote get-url origin 2>$null
  if (-not $gitRemoteUrl) { $gitRemoteUrl = '' }
  $hostRe = if ($REMOTE_TYPE -eq 'gitlab') { 'gitlab\.com' } else { 'github\.com' }
  # supports git@host:owner/repo.git and https://host/owner/repo(.git)
  $slug = ($gitRemoteUrl -replace "^.*$hostRe[:/]+", '') -replace '\.git$', ''
  $slashIdx = $slug.IndexOf('/')
  $rOwner = if ($slashIdx -ge 0) { $slug.Substring(0, $slashIdx) } else { $slug }
  $rRepo = if ($slashIdx -ge 0) { $slug.Substring($slashIdx + 1) } else { '' }
  if ($rOwner -and $rRepo -and $rOwner -ne $slug) {
    & bd config set "$REMOTE_TYPE.owner" $rOwner *> $null
    & bd config set "$REMOTE_TYPE.repo" $rRepo *> $null
    Write-Output "  beads<->$REMOTE_TYPE sync configured ($rOwner/$rRepo; run 'bd $REMOTE_TYPE sync' or push to sync)"
  } else {
    Write-Output "  ! beads<->${REMOTE_TYPE}: no '$REMOTE_TYPE' origin remote yet - add one, then re-run 'aiflow change-settings'"
  }
} elseif ($REMOTE_TYPE -eq 'custom') {
  Write-Output "  beads<->remote: custom host ($REMOTE_URL, api=$REMOTE_API) - Dolt sync via 'refs/dolt/data' on 'origin'; token in `$$REMOTE_TOKENENV"
}

# ---------- rtk (set by aiflow, project-scoped; never global) ----------
if ($RTK_ON) {
  if (Have rtk) {
    & rtk init *> $null
    if ($LASTEXITCODE -eq 0) { Write-Output "  rtk output-filtering enabled (project hook)" }
    else { Write-Output "  ! rtk init failed" }
  } else {
    Write-Output "  ! rtk enabled in config but 'rtk' not installed - see README"
  }
}

# ---------- memory (project aim + dev setup) ----------
if ($MEMORY_ON -or $AIM) {
  New-Item -ItemType Directory -Force -Path '.claude/memory' | Out-Null
  $aimText = if ($AIM) { $AIM } else { '<describe what this project should achieve>' }
  $archText = if ($ARCH) { $ARCH } else { '<describe the intended architecture>' }
  $projectAimMd = @"
# Project aim
**Goal:** $aimText

**Target architecture:** $archText

(Keep this current. Agents read it every session. Detailed view: docs/architecture/.)
"@
  Write-PlainFile '.claude/memory/project-aim.md' ($projectAimMd + "`n")

  $osText = if ($OS) { $OS } else { 'unknown' }
  $ideText = if ($IDE) { $IDE } else { 'unknown' }
  $remoteUrlSuffix = if ($REMOTE_URL) { " ($REMOTE_URL)" } else { '' }
  $devEnvMd = @"
# Dev environment
- **OS:** $osText
- **IDE:** $ideText
- **Version control:** $VCS_SYS
- **Remote host:** $REMOTE_TYPE$remoteUrlSuffix
- **Claude auth:** $CLAUDE_AUTH

Use this to pick correct shell/CLI commands and IDE-specific steps without re-asking.
"@
  Write-PlainFile '.claude/memory/dev-environment.md' ($devEnvMd + "`n")

  # ---- graph-memory learning policy (intensity-driven) ----
  $MEM_RULE = switch ($MEMORY_INT) {
    'aggressive' { 'Learn **aggressively**: after every non-trivial task, save durable facts (decisions, gotchas, env quirks, API shapes) to memory and refresh the graphify graph. Prefer the graph over re-reading files.' }
    'light' { 'Learn **sparingly**: only save high-value, long-lived facts. Refresh the graph on request.' }
    'off' { 'Graph-memory learning is **off**; rely on Beads + this file only.' }
    default { 'Learn at a **normal** pace: save durable non-obvious facts; refresh the graph when structure changes.' }
  }
  $graphifyStatus = if ($GRAPHIFY_ON) { 'enabled' } else { 'disabled' }
  $cocoStatus = if ($COCO_ON) { 'enabled' } else { 'disabled' }
  $ctx7Status = if ($CTX7_ON) { 'enabled' } else { 'disabled' }
  $memPolicyMd = @"
# Memory & context policy
- **Learning intensity:** $MEMORY_INT
- **Graph memory (graphify):** $graphifyStatus
- **RAG code search (cocoindex-code):** $cocoStatus
- **External docs (context7):** $ctx7Status

$MEM_RULE

## Context stack - which source to hit, in order (fewest tokens first)
| Need | Use | Why |
|------|-----|-----|
| Current task, deps, decisions, session state | **Beads** (``bd``) | structured work memory, survives compaction |
| Durable project facts / gotchas / env quirks | **memory files** (this dir) | prose facts not in code/git |
| Where a symbol is defined, who calls it, dependency direction | **graphify** MCP | exact structural graph, no re-scan |
| "Find code about concept X" / semantic / fuzzy | **cocoindex-code** (``ccc search`` / MCP) | AST-aware RAG, ~70% fewer tokens than reading files |
| External library / framework API docs | **context7** MCP | live upstream docs, avoids hallucination |
| Anything still unresolved | read the file(s) | only after graph + RAG have narrowed the target |

**Rule:** never scan whole files first. Route the question through graphify (structure) and
cocoindex-code (semantics) to locate the few relevant chunks, then open only those.
Refresh both indexes with ``aiflow index`` after significant code changes.
"@
  Write-PlainFile '.claude/memory/memory-policy.md' ($memPolicyMd + "`n")

  $memIndexMd = @"
# Project Memory Index
- [Project aim](memory/project-aim.md) - goal + target architecture
- [Dev environment](memory/dev-environment.md) - OS, IDE, VCS, remote, Claude auth
- [Memory policy](memory/memory-policy.md) - learning intensity + graph memory
"@
  Write-PlainFile '.claude/MEMORY.md' ($memIndexMd + "`n")

  # flip AGENTS.md memory toggle on (CLAUDE.md just @-imports AGENTS.md)
  if ((Test-Path 'AGENTS.md') -and (Select-String -Path 'AGENTS.md' -Pattern 'AIFLOW_MEMORY: off' -Quiet)) {
    $agentsContent = Get-Content 'AGENTS.md' -Raw
    $agentsContent = $agentsContent -replace 'AIFLOW_MEMORY: off', 'AIFLOW_MEMORY: on'
    Write-PlainFile 'AGENTS.md' $agentsContent
  }
  Write-Output "  memory written (aim + dev environment + policy: intensity=$MEMORY_INT graph=$($MEMORY_GRAPH.ToString().ToLower()))"
}

# ---------- claude-code-router config (wire Ollama + cost providers so they're used) ----------
if ($ROUTER_ON -or $OLLAMA_ON) {
  New-Item -ItemType Directory -Force -Path '.aiflow' | Out-Null
  $ollamaModels = @()
  if ($cfgObj.ollama -and $cfgObj.ollama.models) { $ollamaModels = @($cfgObj.ollama.models) }
  $ollamaUrlTrimmed = $OLLAMA_URL.TrimEnd('/')
  $routerObj = [ordered]@{}
  if ($OLLAMA_ON -and $ollamaModels.Count -gt 0) {
    $routerObj['Providers'] = @([ordered]@{ name = 'ollama'; api_base_url = "$ollamaUrlTrimmed/v1"; api_key = 'ollama'; models = $ollamaModels })
    $routerObj['Router'] = [ordered]@{ background = "ollama,$($ollamaModels[0])"; default = '' }
  } else {
    $routerObj['Providers'] = @()
    $routerObj['Router'] = [ordered]@{}
  }
  $routerObj['$comment'] = 'Generated by aiflow. Fill real cost-provider keys in ~/.claude-code-router/config.json (never commit). Ollama needs no key.'
  Write-JsonFile '.aiflow/router-config.json' $routerObj
  Write-Output "  router-config.json written (ollama=$($OLLAMA_ON.ToString().ToLower()) models=$($ollamaModels.Count))"
}

# ---------- team/user-wide shared preferences (versioned) ----------
if ($TEAM_ON) {
  if (-not (Test-Path '.aiflow/team-prefs.json')) {
    $teamStyleVal = if ($TEAM_STYLE) { $TEAM_STYLE } else { 'google' }
    $teamObj = [ordered]@{
      '$comment' = 'Shared, versioned team/user preferences. Committed to the repo so the whole team inherits them. Personal overrides stay local (not here).'
      codeStyle  = $teamStyleVal
      language   = 'en'
      conventions = [ordered]@{ commits = 'conventional-commits'; reviewGate = '/review-ac' }
    }
    Write-JsonFile '.aiflow/team-prefs.json' $teamObj
  }
  $tpObj = $null
  try { $tpObj = Get-Content '.aiflow/team-prefs.json' -Raw | ConvertFrom-Json } catch {}
  $tpStyle = if ($tpObj -and $tpObj.codeStyle) { $tpObj.codeStyle } else { 'google' }
  Write-Output "  team-prefs.json present (codeStyle=$tpStyle) - shared across users/teams"
}

# ---------- OS-aware Claude Code hook commands (bash on mac/linux, PowerShell on Windows) ----------
if (Test-Path '.claude/settings.json') {
  if ($OS -eq 'windows') {
    $hookFmt = 'powershell -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/format.ps1'
    $hookCave = 'powershell -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/caveman.ps1'
    $hookBeads = 'powershell -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/beads-sync.ps1'
  } else {
    $hookFmt = 'bash .claude/hooks/format.sh'
    $hookCave = 'bash .claude/hooks/caveman.sh'
    $hookBeads = 'bash .claude/hooks/beads-sync.sh'
  }
  $settingsObj = Get-Content '.claude/settings.json' -Raw | ConvertFrom-Json
  if ($settingsObj.PSObject.Properties.Match('hooks').Count -eq 0) {
    $settingsObj | Add-Member -NotePropertyName hooks -NotePropertyValue ([pscustomobject]@{})
  }
  Set-JsonProperty $settingsObj.hooks 'SessionStart' @(
    [ordered]@{ hooks = @([ordered]@{ type = 'command'; command = $hookCave }, [ordered]@{ type = 'command'; command = $hookBeads }) }
  )
  Set-JsonProperty $settingsObj.hooks 'PostToolUse' @(
    [ordered]@{ matcher = 'Edit|Write'; hooks = @([ordered]@{ type = 'command'; command = $hookFmt }) }
  )
  Write-JsonFile '.claude/settings.json' $settingsObj
  $osLabel = if ($OS) { $OS } else { 'unknown' }
  $shellLabel = if ($OS -eq 'windows') { 'powershell' } else { 'bash' }
  Write-Output "  settings.json hooks wired for OS=$osLabel ($shellLabel)"
}

# ---------- README: "Built with aiflow" badge (idempotent; never touches the rest of the file) ----------
$Badge = '[![Built with aiflow](https://img.shields.io/badge/built%20with-aiflow-6b46c1)](https://github.com/cyber93de/aiflow)'
function Add-Badge($rf) {
  if (-not (Test-Path $rf)) { return }
  $content = Get-Content $rf -Raw
  if ($content -match 'built%20with-aiflow') { return }
  $lines = $content -split "`r?`n"
  if ($lines[0] -match '^# ') {
    $tail = if ($lines.Count -gt 1) { $lines[1..($lines.Count - 1)] } else { @() }
    $newLines = @($lines[0], '', $Badge) + $tail
  } else {
    $newLines = @($Badge, '') + $lines
  }
  Write-PlainFile $rf (($newLines -join "`n") + "`n")
  Write-Output "  ${rf}: added 'Built with aiflow' badge"
}
Add-Badge 'README.md'
Add-Badge 'README.de.md'

# ---------- Beads close -> push + dolt sync rule ----------
# Wire a helper the agent/user runs to honour the 'ask on close' rule. Non-automatic: it prompts.
if ($SYNC_ONCLOSE) {
  New-Item -ItemType Directory -Force -Path '.aiflow' | Out-Null
  $bdCloseSrc = Join-Path $AIFLOW_HOME 'templates/.aiflow/bd-close-sync.ps1'
  if (Test-Path $bdCloseSrc) { Copy-Item -Path $bdCloseSrc -Destination '.aiflow/bd-close-sync.ps1' -Force }
  Write-Output "  bd-close-sync enabled (on issue close: prompt to push + dolt-sync $REMOTE_TYPE)"
}

Write-Output "apply done."
