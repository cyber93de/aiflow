# aiflow - agentic delivery bootstrapper (PowerShell launcher)
$ErrorActionPreference = 'Stop'

$AIFLOW_HOME = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$env:AIFLOW_HOME = $AIFLOW_HOME

function Import-DotEnv {
  if (Test-Path '.env') {
    Get-Content '.env' | ForEach-Object {
      if ($_ -match '^\s*#') { return }
      if ($_ -match '^\s*([^=]+?)\s*=\s*(.*)$') {
        $name = $matches[1].Trim()
        $val  = $matches[2].Trim().Trim('"')
        if ($name) { [Environment]::SetEnvironmentVariable($name, $val, 'Process') }
      }
    }
  }
}

$cmd = if ($args.Count -gt 0) { $args[0] } else { 'help' }
$rest = if ($args.Count -gt 1) { $args[1..($args.Count-1)] } else { @() }

function Test-VersionOlder($a, $b) {
  if ($a -eq $b) { return $false }
  try { return ([version]($a -replace '[^0-9.]','')) -lt ([version]($b -replace '[^0-9.]','')) }
  catch { return $a -ne $b }
}

$skipCheck = @('init','update','project-update','help','-h','--help','version','-v','--version')
if (($skipCheck -notcontains $cmd) -and (Test-Path '.aiflow/config.json') -and [Environment]::UserInteractive) {
  try {
    $projCfg = Get-Content '.aiflow/config.json' -Raw | ConvertFrom-Json
    $projVer = if ($projCfg.meta.aiflowVersion) { $projCfg.meta.aiflowVersion } else { '0.0.0' }
    $toolVer = if (Test-Path (Join-Path $AIFLOW_HOME 'VERSION')) { (Get-Content (Join-Path $AIFLOW_HOME 'VERSION') -TotalCount 1).Trim() } else { '0.0.0' }
    if (Test-VersionOlder $projVer $toolVer) {
      $ans = Read-Host "This project is on aiflow $projVer, installed aiflow is $toolVer. Upgrade project templates now? (y/n) [n]"
      if ($ans -match '^[Yy]') { & bash "$AIFLOW_HOME/lib/project-update.sh" }
      else { Write-Output "  (skipped - run 'aiflow project-update' anytime)" }
    }
  } catch {}
}

switch ($cmd) {
  'init'    { & bash "$AIFLOW_HOME/lib/init.sh" @rest }
  'doctor'  { & bash "$AIFLOW_HOME/lib/doctor.sh" @rest }
  { $_ -in 'change-settings','settings' } { & bash "$AIFLOW_HOME/lib/settings.sh" @rest }
  { $_ -in 'install-deps','setup' } { & bash "$AIFLOW_HOME/lib/install-deps.sh" @rest }
  'upgrade' { & bash "$AIFLOW_HOME/lib/upgrade.sh" @rest }
  'shell'   {
    Import-DotEnv
    if ($rest.Count -gt 0 -and $rest[0] -eq '--router') {
      $r2 = if ($rest.Count -gt 1) { $rest[1..($rest.Count-1)] } else { @() }
      if (-not (Get-Command ccr -ErrorAction SilentlyContinue)) { Write-Error 'claude-code-router not installed: npm i -g @musistudio/claude-code-router'; break }
      & ccr code @r2
    } else { & claude @rest }
  }
  'cost'    { & npx -y ccusage@latest @rest }
  'index'   {
    $did = $false
    if (Get-Command graphify -ErrorAction SilentlyContinue) { Write-Output '>> graphify (structural graph)'; & graphify build .; $did = $true }
    else { Write-Output '  graphify not installed: uv tool install graphifyy && graphify install' }
    if (Get-Command ccc -ErrorAction SilentlyContinue) { Write-Output '>> cocoindex-code (semantic RAG index)'; & ccc index; $did = $true }
    else { Write-Output "  cocoindex-code not installed: uv tool install 'cocoindex-code[full]'" }
    if (-not $did) { Write-Error 'no index tool installed (graphify / cocoindex-code)' }
  }
  'ralph'   {
    Import-DotEnv
    if (Test-Path '.aiflow/ralph-headless.sh') { & bash '.aiflow/ralph-headless.sh' @rest }
    else { Write-Error "No .aiflow/ralph-headless.sh. Run 'aiflow init' first." }
  }
  'security-check' {
    Import-DotEnv
    if (Test-Path '.aiflow/security-check.sh') { & bash '.aiflow/security-check.sh' @rest }
    else { Write-Error "No .aiflow/security-check.sh. Run 'aiflow init' first." }
  }
  { $_ -in 'requirements-check','req-check' } {
    Import-DotEnv
    if (Test-Path '.aiflow/requirements-check.sh') { & bash '.aiflow/requirements-check.sh' @rest }
    else { Write-Error "No .aiflow/requirements-check.sh. Run 'aiflow init' first." }
  }
  { $_ -in 'quality-check','refactor-check' } {
    Import-DotEnv
    if (Test-Path '.aiflow/quality-check.sh') { & bash '.aiflow/quality-check.sh' @rest }
    else { Write-Error "No .aiflow/quality-check.sh. Run 'aiflow init' first." }
  }
  'release' { Import-DotEnv; & bash '.aiflow/release.sh' @rest }
  'protect' { Import-DotEnv; & bash '.aiflow/protect.sh' @rest }
  { $_ -in 'dependency-check','deps-check' } { Import-DotEnv; & bash '.aiflow/run-agent.sh' dependency-auditor @rest }
  'test-gap'   { Import-DotEnv; & bash '.aiflow/run-agent.sh' test-gap-advisor @rest }
  'perf-check' { Import-DotEnv; & bash '.aiflow/run-agent.sh' performance-advisor @rest }
  'docs-check' { Import-DotEnv; & bash '.aiflow/run-agent.sh' docs-sync @rest }
  'onboard'    { Import-DotEnv; & bash '.aiflow/run-agent.sh' onboarder @rest }
  'sync'       {
    $dir = if ($rest.Count -ge 1) { $rest[0] } else { 'both' }
    if (Test-Path .git) { if ($dir -ne 'push') { Write-Output '>> git pull --rebase'; & git pull --rebase } }
    if ((Get-Command bd -ErrorAction SilentlyContinue) -and (Test-Path .beads)) {
      if ($dir -ne 'push') { Write-Output '>> bd dolt pull'; & bd dolt pull }
      if ($dir -eq 'push' -or $dir -eq 'both') {
        Write-Output '>> bd dolt push'; & bd dolt pull *> $null; & bd dolt push
        if (Test-Path .git) { Write-Output '>> git push'; & git push }
      }
    }
  }
  'ollama'     { & bash "$AIFLOW_HOME/lib/ollama.sh" @rest }
  'update'     { & bash "$AIFLOW_HOME/lib/update.sh" @rest }
  'project-update' { & bash "$AIFLOW_HOME/lib/project-update.sh" @rest }
  { $_ -in 'close-sync','bd-sync' } {
    if (Test-Path '.aiflow/bd-close-sync.sh') { & bash '.aiflow/bd-close-sync.sh' @rest }
    else { Write-Error "No .aiflow/bd-close-sync.sh (enable sync-on-close via 'aiflow change-settings')." }
  }
  { $_ -in 'version','-v','--version' } {
    $vf = Join-Path $AIFLOW_HOME 'VERSION'
    $ver = if (Test-Path $vf) { (Get-Content $vf -TotalCount 1).Trim() } else { '0.0.0' }
    Write-Output "aiflow $ver"
  }
  default {
@'
aiflow - bootstrap agentic delivery into any project (Claude Code + Beads + Ralph + GitHub)

USAGE
  aiflow init [path] [--force] [--no-git] [--no-beads] [--yes]
  aiflow install-deps [--all]  install missing tools (enabled in config; --all = full set)
  aiflow change-settings   re-adjust this project's config (alias: settings)
  aiflow shell [--router]  load .env then launch Claude Code (--router = claude-code-router)
  aiflow ralph [...]       run the headless Ralph loop in this project
  aiflow security-check    full-project security audit -> files Beads issues per finding
  aiflow requirements-check  advisory audit of issue quality/completeness (report only)
  aiflow quality-check     code quality/refactoring audit -> files [technical issue] Beads
  aiflow dependency-check  deps audit (vulns/outdated/unused/license) -> [dependency] Beads
  aiflow test-gap          untested critical paths -> [test gap] Beads
  aiflow perf-check        performance audit -> [performance] Beads
  aiflow docs-check        doc/code drift -> [docs] Beads
  aiflow onboard           learn an existing codebase into memory + CLAUDE.md + arc42
  aiflow sync [pull|push|both]  team sync: git + Beads(dolt) pull/push (default pull at start)
  aiflow ollama [pull|add <m>|list]  manage local Ollama models (from config)
  aiflow close-sync <id>   on Beads issue close: prompt to push + dolt-sync the remote
  aiflow release [--push]  cut a release per the branching model (version bump + tag)
  aiflow protect           apply server-side branch protection (GitHub)
  aiflow cost [...]        token/cost baseline via ccusage
  aiflow index             refresh code memory: graphify (structural graph) + cocoindex (RAG)
  aiflow upgrade           update the bundled toolchain to latest
  aiflow update            self-update the aiflow install itself (git pull) to the latest release
  aiflow project-update    refresh THIS project's aiflow scripts from the installed templates
  aiflow doctor            check prerequisites
  aiflow version
'@ | Write-Output
  }
}
