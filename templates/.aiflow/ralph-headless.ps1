# Headless Ralph Wiggum loop via open-ralph-wiggum (github.com/Th0rgal/open-ralph-wiggum) -
# agent-agnostic: works with Claude Code, OpenAI Codex CLI, or GitHub Copilot CLI through a
# single --agent flag. ralph itself owns the outer loop (iterations, restart, promise
# detection, .ralph/ralph-history.json) - this script just builds the task prompt and picks a
# default agent from .aiflow/config.json's agents.* if the caller didn't pass --agent.
# Usage: aiflow ralph "<prompt or bead id>" [ralph flags..., e.g. --agent codex --tasks]
$ErrorActionPreference = 'Continue'

if ($args.Count -lt 1 -or -not $args[0]) { Write-Error 'usage: aiflow ralph "<prompt or bead id>" [ralph flags...]'; exit 2 }
$prompt = $args[0]
$rest = if ($args.Count -gt 1) { $args[1..($args.Count - 1)] } else { @() }

if (-not (Get-Command ralph -ErrorAction SilentlyContinue)) {
  Write-Error "ERROR: 'ralph' CLI not found - npm i -g @th0rgal/ralph-wiggum (needs Bun: https://bun.sh)"
  exit 3
}

$max = if ($env:RALPH_MAX_ITERATIONS) { $env:RALPH_MAX_ITERATIONS } else { "50" }

# Default --agent from .aiflow/config.json's agents.* (claude > codex > copilot priority)
# unless the caller already passed --agent explicitly.
$agentFlag = @()
if ($rest -notcontains "--agent") {
  if (Test-Path ".aiflow/config.json") {
    try {
      $cfg = Get-Content ".aiflow/config.json" -Raw | ConvertFrom-Json
      if ($null -eq $cfg.agents.claude -or $cfg.agents.claude) { $agentFlag = @("--agent", "claude-code") }
      elseif ($cfg.agents.codex)   { $agentFlag = @("--agent", "codex") }
      elseif ($cfg.agents.copilot) { $agentFlag = @("--agent", "copilot") }
    } catch {}
  } else {
    $agentFlag = @("--agent", "claude-code")
  }
}

$guard = @'

--- AIFLOW CONTEXT (ralph's own prompt template adds the completion-promise instruction -
don't duplicate it here, that only confuses where the tag ends up) ---
You run unattended in a loop; each iteration you see your own previous work in files and git
history. Make concrete progress toward the task, respecting AGENTS.md (architecture, Google
style, acceptance criteria, tests). Use Beads (bd) to track state; commit your work referencing
bead ids. Never invent scope beyond the acceptance criteria.
'@

Write-Output ">> ralph (open-ralph-wiggum): $(if ($agentFlag) { $agentFlag[1] } else { 'default agent from config' }), max $max iterations"
& ralph "TASK: $prompt`n$guard" --completion-promise COMPLETE --abort-promise BLOCKED --max-iterations $max @agentFlag @rest
exit $LASTEXITCODE
