# aiflow doctor - check prerequisites
$ErrorActionPreference = 'SilentlyContinue'

function Test-Have($name) { [bool](Get-Command $name -ErrorAction SilentlyContinue) }

# never let a --version probe hang (mirrors lib/doctor.sh's `timeout 5` guard).
# Start-Job runs in a separate runspace with no real console stdin, and several
# CLIs here (claude, gh, bd, ralph, ...) wait on stdin in that context and never
# return - so this uses a real child process with stdin closed immediately instead.
# Bare npm-shim names (copilot, codex, ralph, ...) resolve to a .ps1/.cmd pair, not
# a directly-launchable .exe, so Process.Start needs the resolved file dispatched
# through the right host (cmd.exe for .cmd, powershell.exe for .ps1).
function Get-VersionLine($cmdName) {
  $cmd = Get-Command $cmdName -All -ErrorAction SilentlyContinue |
    Sort-Object { switch ($_.Extension) { '.exe' {0} '.cmd' {1} '.bat' {1} default {2} } } |
    Select-Object -First 1
  if (-not $cmd) { return "" }
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  switch ($cmd.Extension) {
    { $_ -in '.cmd', '.bat' } { $psi.FileName = 'cmd.exe'; $psi.Arguments = "/c `"$($cmd.Source)`" --version" }
    '.ps1' { $psi.FileName = 'powershell.exe'; $psi.Arguments = "-NoProfile -NonInteractive -File `"$($cmd.Source)`" --version" }
    default { $psi.FileName = $cmd.Source; $psi.Arguments = '--version' }
  }
  $psi.RedirectStandardInput = $true
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  try { $p = [System.Diagnostics.Process]::Start($psi) } catch { return "" }
  try { $p.StandardInput.Close() } catch {}
  $stdoutTask = $p.StandardOutput.ReadToEndAsync()
  if (-not $p.WaitForExit(5000)) {
    try { $p.Kill() } catch {}
    return ""
  }
  $out = $stdoutTask.GetAwaiter().GetResult()
  if ([string]::IsNullOrWhiteSpace($out)) { return "" }
  return (($out -split "`r?`n" | Where-Object { $_ }) | Select-Object -First 1)
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

# Null-check only (NOT jq's `//` semantics): an explicitly-set `false` must survive the
# default instead of being collapsed to it (aiflow-5qe - lib/doctor.sh fixed the same way).
function Get-JVal($obj, $path, $default) {
  $cur = $obj
  foreach ($seg in $path -split '\.') {
    if ($null -eq $cur) { break }
    $cur = $cur.$seg
  }
  if ($null -eq $cur) { $cur = $default }
  if ($cur -is [bool]) { return $(if ($cur) { 'true' } else { 'false' }) }
  return $cur
}

$cfgObj = $null
if (Test-Path '.aiflow/config.json') {
  try { $cfgObj = Get-Content '.aiflow/config.json' -Raw | ConvertFrom-Json } catch { $cfgObj = $null }
}

if ($cfgObj) {
  Write-Output ""
  Write-Output "this project (.aiflow/config.json):"
  $ponytailStatus = if ((Get-JVal $cfgObj "ponytail.enabled" $false) -eq 'true') { Get-JVal $cfgObj "ponytail.mode" "full" } else { "off" }
  Write-Output ("  agents:  claude={0} copilot={1} codex={2}  codexsaver={3}  modelRouting={4}  ponytail={5}" -f `
    (Get-JVal $cfgObj "agents.claude" $true), `
    (Get-JVal $cfgObj "agents.copilot" $false), `
    (Get-JVal $cfgObj "agents.codex" $false), `
    (Get-JVal $cfgObj "codexsaver.enabled" $false), `
    (Get-JVal $cfgObj "modelRouting.enabled" $true), `
    $ponytailStatus)
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
