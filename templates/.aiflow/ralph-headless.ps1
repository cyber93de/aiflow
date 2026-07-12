# Headless Ralph Wiggum loop: iterate Claude Code until COMPLETE or BLOCKED.
# Usage: aiflow ralph "<prompt or bead id>"
#        powershell -File .aiflow/ralph-headless.ps1 "<prompt>"
# Reads tokens/tuning from env (.env is loaded by `aiflow ralph`).
$ErrorActionPreference = 'Continue'

$prompt = ($args -join " ").Trim()
if (-not $prompt) { Write-Error 'usage: aiflow ralph "<prompt or bead id>"'; exit 2 }

$max = if ($env:RALPH_MAX_ITERATIONS) { [int]$env:RALPH_MAX_ITERATIONS } else { 50 }
$timeout = if ($env:RALPH_TIMEOUT_SECONDS) { [int]$env:RALPH_TIMEOUT_SECONDS } else { 3600 }
$mode = if ($env:RALPH_PERMISSION_MODE) { $env:RALPH_PERMISSION_MODE } else { "acceptEdits" }
$result = "result.json"
$start = Get-Date

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) { Write-Error "ERROR: 'claude' CLI not found"; exit 3 }
if (-not $env:CLAUDE_CODE_OAUTH_TOKEN -and -not $env:ANTHROPIC_API_KEY) {
  Write-Output "note: no token in env; relying on stored Claude login. For CI set a token (see .env)."
}

$guard = @'

--- RALPH LOOP PROTOCOL ---
You run unattended in a loop. Each iteration:
1. If result.json exists, read it to recover where you left off.
2. Make concrete progress toward the task. Respect CLAUDE.md (architecture, Google style,
   acceptance criteria, tests). Use Beads (bd) to track state.
3. Before finishing THIS iteration, OVERWRITE result.json (valid JSON) with:
   { "status": "IN_PROGRESS" | "COMPLETE" | "BLOCKED",
     "summary": "<what changed this iteration>",
     "next": "<what to do next, or empty>",
     "blocker": "<why blocked, only if BLOCKED>" }
Rules: COMPLETE only when ALL acceptance criteria are met, tests pass, style/lint clean,
and the review gate would pass. BLOCKED if you need a human decision or missing access.
Never invent scope beyond the acceptance criteria. Commit your work (reference bead ids).
'@

$status = "IN_PROGRESS"
for ($i = 1; $i -le $max; $i++) {
  $elapsed = ((Get-Date) - $start).TotalSeconds
  if ($elapsed -ge $timeout) {
    '{"status":"BLOCKED","blocker":"timeout after ' + $timeout + 's"}' | Set-Content $result
    $status = "BLOCKED"; break
  }

  Write-Output ">> Ralph iteration $i/$max  (elapsed $([int]$elapsed)s)"
  & claude -p "TASK: $prompt`n$guard" --permission-mode $mode --output-format json *> $null 2>>".aiflow/ralph.log"

  if (Test-Path $result) {
    try {
      $r = Get-Content $result -Raw | ConvertFrom-Json
      $status = if ($r.status) { $r.status } else { "IN_PROGRESS" }
    } catch { $status = "IN_PROGRESS" }
  }
  Write-Output "   status=$status"
  if ($status -eq "COMPLETE" -or $status -eq "BLOCKED") { break }
}

Write-Output "== Ralph finished: $status =="
if (Test-Path $result) { Get-Content $result }
switch ($status) {
  "COMPLETE" { exit 0 }
  "BLOCKED"  { exit 1 }
  default    { exit 2 }
}
