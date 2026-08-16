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

# ---- Windows: WSL is where native builds belong, never MinGW (aiflow-53b) ----
Write-Output ""
Write-Output "windows native-build toolchain (WSL, not MinGW):"
$v2 = 0
if (-not (Test-Have wsl)) {
  Write-Output ("  [MISS] {0,-10} -> WSL not available. Admin PowerShell: wsl --install   (then reboot)" -f "wsl")
  Write-Output ("  [----] {0,-10}    then: wsl --install -d Ubuntu" -f "")
} else {
  # wsl.exe emits UTF-16LE; force the console decoder so the names are readable.
  $prevEnc = [Console]::OutputEncoding
  try { [Console]::OutputEncoding = [System.Text.Encoding]::Unicode } catch {}
  $distros = @(& wsl.exe -l -q 2>$null | ForEach-Object { $_.Trim() } | Where-Object { $_ })
  $verbose = @(& wsl.exe -l -v 2>$null | ForEach-Object { $_.Trim() } | Where-Object { $_ })
  try { [Console]::OutputEncoding = $prevEnc } catch {}
  if ($distros.Count -eq 0) {
    Write-Output ("  [MISS] {0,-10} -> WSL present but no distribution installed: wsl --install -d Ubuntu" -f "wsl distro")
  } else {
    Write-Output ("  [ok]   {0,-10} distros: {1}" -f "wsl", ($distros -join " "))
    $v2 = @($verbose | Select-Object -Skip 1 | Where-Object { $_ -match '\s2\s*$' }).Count
    if ($v2 -gt 0) { Write-Output ("  [ok]   {0,-10} {1} distro(s) on WSL2" -f "wsl2", $v2) }
    else { Write-Output ("  [MISS] {0,-10} -> distro is on WSL1: wsl --set-default-version 2 && wsl --set-version <distro> 2" -f "wsl2") }
    # gcc/g++ must live INSIDE the distro, not on the Windows PATH
    $gcc = (& wsl.exe -e sh -c "command -v gcc >/dev/null && command -v g++ >/dev/null && gcc --version | head -n1" 2>$null)
    if ($LASTEXITCODE -eq 0 -and $gcc) { Write-Output ("  [ok]   {0,-10} {1}" -f "gcc/g++", ($gcc | Select-Object -First 1)) }
    else { Write-Output ("  [MISS] {0,-10} -> in WSL: sudo apt update && sudo apt install -y build-essential" -f "gcc/g++") }
  }
}
# Hardware virtualisation - WSL2 cannot run without it, and the BIOS switch is easy to miss.
# A running WSL2 distro is proof enough; only pay for the WMI probe when it isn't.
if ($v2 -gt 0) {
  Write-Output ("  [ok]   {0,-10} enabled (a WSL2 distro is running)" -f "vt-x/svm")
} else {
  $vt = (Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1).VirtualizationFirmwareEnabled
  if ($vt -eq $true)       { Write-Output ("  [ok]   {0,-10} enabled in BIOS/UEFI" -f "vt-x/svm") }
  elseif ($vt -eq $false)  { Write-Output ("  [MISS] {0,-10} -> enable Intel VT-x / AMD SVM Mode in the BIOS/UEFI, then reboot" -f "vt-x/svm") }
  else                     { Write-Output ("  [----] {0,-10} could not determine (Task Manager -> Performance -> CPU -> Virtualization)" -f "vt-x/svm") }
}
# A MinGW/MSYS2 gcc on the Windows PATH is exactly what we do not want people using.
if (Test-Have gcc) {
  $triple = (& gcc -dumpmachine 2>$null | Select-Object -First 1)
  if ($triple -match 'mingw|msys') {
    Write-Output ("  [warn] {0,-10} MinGW/MSYS gcc on PATH ({1}) - build native code in WSL instead" -f "mingw", $triple)
  }
}
Write-Output "  docs: https://cyber93de.github.io/aiflow/installation#windows-prerequisites-do-this-first"

Write-Output ""
Write-Output "task / memory / vcs:"
Invoke-Check "task-master" "task-master" "claude-task-master: npm i -g task-master-ai"
Invoke-Check "graphify" "graphify" "structural code graph: uv tool install graphifyy && graphify install (repo: https://github.com/Graphify-Labs/graphify)"
Invoke-Check "ccc"     "ccc"     "cocoindex-code (semantic RAG): uv tool install 'cocoindex-code[full]'"
Invoke-Check "uv"      "uv"      "https://docs.astral.sh/uv/ (installs graphify + cocoindex-code)"
Invoke-Check "gh"      "gh"      "GitHub CLI: https://cli.github.com (only if remote=github)"
Invoke-Check "glab"    "glab"    "GitLab CLI: https://gitlab.com/gitlab-org/cli (only if remote=gitlab)"
Invoke-Check "svn"     "svn"     "Subversion (only if vcs.system=svn)"
Invoke-Check "ollama"  "ollama"  "local models: https://ollama.com/download (only if ollama enabled)"

Write-Output ""
Write-Output "cost / token-efficiency stack:"
Invoke-Check "ccr"     "ccr"     "claude-code-router: npm i -g @musistudio/claude-code-router"
Invoke-Check "rtk"     "rtk"     "rtk output filter: https://github.com/rtk-ai/rtk (aiflow enables it per project)"
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
Write-Output "git hooks:"
# core.hooksPath lives in .git/config, which is never cloned - so a fresh clone silently runs
# no hooks at all until someone sets it. `aiflow apply` does it; a clone needs it again.
& git rev-parse --is-inside-work-tree *> $null
if ($LASTEXITCODE -eq 0) {
  $hp = (& git config --get core.hooksPath) 2>$null
  if ($hp -and (Test-Path $hp)) {
    Write-Output "  [ok]   core.hooksPath=$hp"
  } else {
    $hint = ".githooks"
    if ((Test-Path ".beads/hooks") -and -not (Test-Path ".githooks")) { $hint = ".beads/hooks" }
    Write-Output "  [----] core.hooksPath is not set - commit/push rules do NOT run in this clone"
    Write-Output "         fix: git config core.hooksPath $hint   (or: aiflow apply)"
  }
} else {
  Write-Output "  [----] not a git work tree"
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
