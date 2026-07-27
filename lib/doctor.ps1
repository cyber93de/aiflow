# aiflow doctor - check prerequisites
$ErrorActionPreference = 'SilentlyContinue'

function Test-Have($name) { [bool](Get-Command $name -ErrorAction SilentlyContinue) }

# never let a --version probe hang (mirrors lib/doctor.sh's `timeout 5` guard)
function Get-VersionLine($cmdName) {
  $job = Start-Job -ScriptBlock { param($c) & $c --version 2>$null } -ArgumentList $cmdName
  $out = $null
  if (Wait-Job $job -Timeout 5) { $out = Receive-Job $job } else { Stop-Job $job | Out-Null }
  Remove-Job $job -Force | Out-Null
  if ($out) { return ($out | Select-Object -First 1) }
  return ""
}

function Invoke-Check($name, $cmdName, $hint) {
  if (Test-Have $cmdName) {
    Write-Output ("  [ok]   {0,-10} {1}" -f $name, (Get-VersionLine $cmdName))
  } else {
    Write-Output ("  [MISS] {0,-10} -> {1}" -f $name, $hint)
  }
}

Write-Output "aiflow doctor"
Write-Output "core:"
Invoke-Check "claude"  "claude"  "npm i -g @anthropic-ai/claude-code"
Invoke-Check "copilot" "copilot" "GitHub Copilot CLI: npm i -g @github/copilot (only if agents.copilot enabled)"
Invoke-Check "codex"   "codex"   "OpenAI Codex CLI: npm i -g @openai/codex (only if agents.codex enabled)"
Invoke-Check "git"     "git"     "https://git-scm.com"
Invoke-Check "node"    "node"    "https://nodejs.org (LTS)"
Invoke-Check "jq"      "jq"      "https://jqlang.github.io/jq/ (required to read .aiflow/config.json)"
Invoke-Check "bd"      "bd"      "Beads: https://github.com/steveyegge/beads (or /beads:init in Claude)"
Invoke-Check "ralph"   "ralph"   "Ralph loop (open-ralph-wiggum): npm i -g @th0rgal/ralph-wiggum (needs bun)"
Invoke-Check "codexsaver" "codexsaver" "cost-aware Codex CLI router (only if codexsaver.enabled): https://github.com/fendouai/CodexSaver"
Invoke-Check "bun"     "bun"     "runtime for the Ralph loop: https://bun.sh"
Invoke-Check "dolt"    "dolt"    "Beads backend (bd runs a dolt sql-server): https://docs.dolthub.com/introduction/installation"
if (Test-Have podman) { Invoke-Check "podman" "podman" "container engine for GitHub MCP + headless runs" }
else { Invoke-Check "docker" "docker" "container engine (or Podman): GitHub MCP + headless runs" }

Write-Output ""
Write-Output "task / memory / vcs:"
Invoke-Check "task-master" "task-master" "claude-task-master: npm i -g task-master-ai"
Invoke-Check "graphify" "graphify" "structural code graph: uv tool install graphifyy && graphify install"
Invoke-Check "ccc"     "ccc"     "cocoindex-code (semantic RAG): uv tool install 'cocoindex-code[full]'"
Invoke-Check "uv"      "uv"      "https://docs.astral.sh/uv/ (installs graphify + cocoindex-code)"
Invoke-Check "gh"      "gh"      "GitHub CLI: https://cli.github.com (only if remote=github)"
Invoke-Check "glab"    "glab"    "GitLab CLI: https://gitlab.com/gitlab-org/cli (only if remote=gitlab)"
Invoke-Check "svn"     "svn"     "Subversion (only if vcs.system=svn)"
Invoke-Check "ollama"  "ollama"  "local models: https://ollama.com/download (only if ollama enabled)"

Write-Output ""
Write-Output "cost / token-efficiency stack:"
Invoke-Check "ccr"     "ccr"     "claude-code-router: npm i -g @musistudio/claude-code-router"
Invoke-Check "rtk"     "rtk"     "rtk output filter: see rtk-ai.app (aiflow enables it per project)"
if (Test-Have npx) {
  Write-Output "  [ok]   ccusage    via 'aiflow cost'"
  Write-Output "  [ok]   templates  via 'npx claude-code-templates@latest'"
} else {
  Write-Output "  [MISS] npx        needs node (for ccusage + claude-code-templates)"
}

# Get-JVal mirrors jq's `//` operator exactly, including its documented quirk of
# treating an explicit `false` the same as a missing/null value (see aiflow-5qe -
# this is a known upstream jq-idiom bug in lib/doctor.sh, reproduced here on purpose
# for behavioral parity rather than silently fixed).
function Get-JVal($obj, $path, $default) {
  $cur = $obj
  foreach ($seg in $path -split '\.') {
    if ($null -eq $cur) { break }
    $cur = $cur.$seg
  }
  if ($null -eq $cur -or $cur -eq $false) { return $default }
  return $cur
}

$cfgObj = $null
if (Test-Path '.aiflow/config.json') {
  try { $cfgObj = Get-Content '.aiflow/config.json' -Raw | ConvertFrom-Json } catch { $cfgObj = $null }
}

if ($cfgObj) {
  Write-Output ""
  Write-Output "this project (.aiflow/config.json):"
  Write-Output ("  agents:  claude={0} copilot={1} codex={2}  codexsaver={3}" -f `
    (Get-JVal $cfgObj "agents.claude" $true), `
    (Get-JVal $cfgObj "agents.copilot" $false), `
    (Get-JVal $cfgObj "agents.codex" $false), `
    (Get-JVal $cfgObj "codexsaver.enabled" $false))
  $baseUrl = Get-JVal $cfgObj "remote.baseUrl" ""
  if ([string]::IsNullOrEmpty($baseUrl)) { $baseUrl = "public" }
  Write-Output ("  remote:  {0} ({1}) - host MCP: {2}" -f `
    (Get-JVal $cfgObj "remote.type" "?"), $baseUrl, (Get-JVal $cfgObj "remote.mcp" "none"))
  $ollamaLine = "off"
  if ($cfgObj.ollama -and $cfgObj.ollama.enabled) { $ollamaLine = (@($cfgObj.ollama.models) -join ",") }
  Write-Output ("  vcs:     {0}   ollama: {1}" -f (Get-JVal $cfgObj "vcs.system" "git"), $ollamaLine)
  Write-Output ("  memory:  graph(graphify)={0}  rag(cocoindex)={1}  context7={2}  intensity={3}" -f `
    (Get-JVal $cfgObj "graphify.enabled" $false), `
    (Get-JVal $cfgObj "mcp.cocoindex" $false), `
    (Get-JVal $cfgObj "mcp.context7" $false), `
    (Get-JVal $cfgObj "memory.intensity" "normal"))
}

Write-Output ""
Write-Output "env:"
$envVars = @("GITHUB_TOKEN", "GITLAB_TOKEN", "GIT_REMOTE_TOKEN", "ANTHROPIC_API_KEY", "CLAUDE_CODE_OAUTH_TOKEN", "CONTEXT7_API_KEY")
if ($cfgObj) {
  $rtok = Get-JVal $cfgObj "remote.tokenEnv" ""
  if ($rtok -and ($envVars -notcontains $rtok)) { $envVars += $rtok }
}
foreach ($v in $envVars) {
  $val = [Environment]::GetEnvironmentVariable($v)
  if ($val) { Write-Output "  [set]  $v" }
  else { Write-Output "  [----] $v (not in shell env; .env is loaded by 'aiflow shell')" }
}
