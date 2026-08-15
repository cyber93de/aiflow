# Generic headless runner: run a named aiflow agent over the whole project.
# The agent's behaviour (what it scans, what it may write) is defined in
# .claude/agents/<name>.md - this just invokes it. Usage: run-agent.ps1 <agent> [focus...]
$ErrorActionPreference = 'Stop'

if ($args.Count -lt 1) { Write-Error "usage: run-agent.ps1 <agent-name> [focus]"; exit 2 }
$agentName = $args[0]
$focus = if ($args.Count -gt 1) { ($args[1..($args.Count - 1)] -join " ") } else { "" }

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) { Write-Error "ERROR: 'claude' CLI not found"; exit 3 }
if (-not $env:CLAUDE_CODE_OAUTH_TOKEN -and -not $env:ANTHROPIC_API_KEY) {
  Write-Output "note: no token in env; relying on stored Claude login."
}
if (-not (Test-Path ".claude/agents/$agentName.md")) {
  Write-Output "note: .claude/agents/$agentName.md not found; relying on the agent name."
}

$mode = if ($env:RALPH_PERMISSION_MODE) { $env:RALPH_PERMISSION_MODE } else { "acceptEdits" }
$focusClause = if ($focus) { "Focus on: $focus. " } else { "" }
$prompt = "Act as the $agentName agent defined in .claude/agents/$agentName.md and follow that definition exactly, operating over the whole project. ${focusClause}Strictly obey the agent's rules about what it may modify - most auditor agents only create Beads issues and must not change code or other issues. Finish with the agent's specified summary."

Write-Output ">> running $agentName..."
& claude -p $prompt --permission-mode $mode
Write-Output ">> $agentName done."
