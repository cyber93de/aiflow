# aiflow project-update - refresh THIS project's aiflow-generated files from the installed
# templates, then re-apply config.
#
# Refreshed (mechanical, always safe to overwrite): .aiflow/*.sh+ps1, .claude/hooks/*.sh+ps1,
# docker/run.sh+ps1, .github/scripts/* (aiflow's CI helpers - not meant to be edited).
# Refreshed (agent definitions - see backup rule below): AGENTS.md, CLAUDE.md,
# .github/copilot-instructions.md, .claude/agents/*.md, .claude/commands/*.md,
# .claude/skills/*/SKILL.md.
# Backup rule: if a refreshed agent-definition file already differs from the incoming template
# (i.e. you customised it, or it's genuinely changed upstream), the OLD file is renamed to
# "<file>.bak" (never deleted) before the new one is written, and reported at the end so you can
# diff/reapply your customisations. Identical files are overwritten silently (nothing lost).
# NEVER touched: .beads/ (issues), .claude/memory/* (project aim, conventions, codebase map, ...),
# .github/workflows/* (yours to extend - see below), .githooks/* (enforcement policy you are
# expected to tune; refreshing it would need the .bak rule and a decision of its own - aiflow-y23,
# so a hook improvement reaches an existing project only if you copy it yourself), and
# .aiflow/config.json's own content (only meta.aiflowVersion is stamped at the end) - your project
# aim, task history, and learned memory always survive a project-update.
#
# Why scripts but not workflows: the helpers aiflow ships into .github/scripts/ are mechanical and
# not meant to be edited, so they are simply overwritten. .github/workflows/ci.yml ships as a
# starting point that projects are expected to extend with their own jobs - overwriting it (or
# even backing it up and replacing it) would throw that away on every update. So a workflow step
# that needs a new helper is ADVISED at the very end of this run, never written. The one-way
# coupling is deliberate: the script is always present, so a project that adopts the step never
# hits a missing file; a project that ignores the advice just carries an unused script.
# Caveat: unlike .aiflow/ or .claude/hooks/, .github/scripts/ is a conventional shared directory,
# not an aiflow-owned namespace. A project file whose NAME collides with a shipped helper is
# overwritten without a .bak - so keep your own CI scripts under a name aiflow does not ship
# (today: check-frontmatter.py), or in a directory of your own.
$ErrorActionPreference = 'Stop'

$AIFLOW_HOME = if ($env:AIFLOW_HOME) { $env:AIFLOW_HOME } else { Split-Path -Parent $PSScriptRoot }
$TPL = Join-Path $AIFLOW_HOME 'templates'
$CFG = ".aiflow/config.json"
if (-not (Test-Path $CFG)) { [Console]::Error.WriteLine("no $CFG - run 'aiflow init' first"); exit 1 }

function Set-JsonProperty($obj, $name, $value) {
  if ($obj.PSObject.Properties.Match($name).Count -gt 0) { $obj.$name = $value }
  else { $obj | Add-Member -NotePropertyName $name -NotePropertyValue $value }
}

function Write-JsonFile($path, $obj) {
  $json = $obj | ConvertTo-Json -Depth 20
  $full = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $path))
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($full, $json, $utf8NoBom)
}

Write-Output ">> aiflow project-update: refreshing mechanical scripts from templates..."
New-Item -ItemType Directory -Force -Path '.aiflow', '.claude/hooks', 'docker' | Out-Null

function Copy-Twins($srcDir, $destDir, $names) {
  New-Item -ItemType Directory -Force -Path $destDir | Out-Null
  foreach ($n in $names) {
    $src = Join-Path $srcDir $n
    if (Test-Path $src) { Copy-Item -Path $src -Destination (Join-Path $destDir $n) -Force }
  }
}

$aiflowSrc = Join-Path $TPL '.aiflow'
if (Test-Path $aiflowSrc) {
  Get-ChildItem -Path $aiflowSrc -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -eq '.sh' -or $_.Extension -eq '.ps1' } |
    ForEach-Object { Copy-Item -Path $_.FullName -Destination (Join-Path '.aiflow' $_.Name) -Force }
}
$hooksSrc = Join-Path $TPL '.claude/hooks'
if (Test-Path $hooksSrc) {
  Get-ChildItem -Path $hooksSrc -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -eq '.sh' -or $_.Extension -eq '.ps1' } |
    ForEach-Object { Copy-Item -Path $_.FullName -Destination (Join-Path '.claude/hooks' $_.Name) -Force }
}
Copy-Twins (Join-Path $TPL 'docker') 'docker' @('run.sh', 'run.ps1')
$ciScriptsSrc = Join-Path $TPL '.github/scripts'
if (Test-Path $ciScriptsSrc) {
  New-Item -ItemType Directory -Force -Path '.github/scripts' | Out-Null
  # copy the CONTENTS, so a subdirectory is merged rather than nested one level deeper per run
  Copy-Item -Path (Join-Path $ciScriptsSrc '*') -Destination '.github/scripts' -Recurse -Force
}
# no chmod +x equivalent needed on Windows - the exec bit is a POSIX concept.
Write-Output "   scripts refreshed"

# ---- agent definitions: back up before overwrite if the existing file was customised ----
Write-Output ">> refreshing agent definitions (customised files are kept as *.bak)..."
$script:added = @()
$script:backedUp = @()

function Test-FilesEqual($a, $b) {
  if (-not (Test-Path $a) -or -not (Test-Path $b)) { return $false }
  $ha = (Get-FileHash -Path $a -Algorithm SHA256).Hash
  $hb = (Get-FileHash -Path $b -Algorithm SHA256).Hash
  return $ha -eq $hb
}

function Update-WithBackup($src, $dest) {
  if (-not (Test-Path $src)) { return }
  $destDir = Split-Path -Parent $dest
  if ($destDir -and -not (Test-Path $destDir)) { New-Item -ItemType Directory -Force -Path $destDir | Out-Null }
  if (-not (Test-Path $dest)) {
    Copy-Item -Path $src -Destination $dest -Force
    $script:added += $dest
  } elseif (-not (Test-FilesEqual $src $dest)) {
    Move-Item -Path $dest -Destination "$dest.bak" -Force
    Copy-Item -Path $src -Destination $dest -Force
    $script:backedUp += $dest
  }
  # identical: nothing to do, no customisation lost
}

Update-WithBackup (Join-Path $TPL 'AGENTS.md') 'AGENTS.md'
Update-WithBackup (Join-Path $TPL 'CLAUDE.md') 'CLAUDE.md'
Update-WithBackup (Join-Path $TPL '.github/copilot-instructions.md') '.github/copilot-instructions.md'

$agentsSrc = Join-Path $TPL '.claude/agents'
if (Test-Path $agentsSrc) {
  Get-ChildItem -Path $agentsSrc -Filter '*.md' -File -ErrorAction SilentlyContinue | ForEach-Object {
    Update-WithBackup $_.FullName (Join-Path '.claude/agents' $_.Name)
  }
}
$commandsSrc = Join-Path $TPL '.claude/commands'
if (Test-Path $commandsSrc) {
  Get-ChildItem -Path $commandsSrc -Filter '*.md' -File -ErrorAction SilentlyContinue | ForEach-Object {
    Update-WithBackup $_.FullName (Join-Path '.claude/commands' $_.Name)
  }
}
$skillsSrc = Join-Path $TPL '.claude/skills'
if (Test-Path $skillsSrc) {
  Get-ChildItem -Path $skillsSrc -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $skillFile = Join-Path $_.FullName 'SKILL.md'
    if (Test-Path $skillFile) {
      Update-WithBackup $skillFile (Join-Path ".claude/skills/$($_.Name)" 'SKILL.md')
    }
  }
}

if ($script:added.Count -gt 0) {
  Write-Output ("   new: " + ($script:added -join " "))
}
if ($script:backedUp.Count -gt 0) {
  Write-Output ""
  Write-Output ("   !! {0} customised file(s) were REPLACED with the new template version." -f $script:backedUp.Count)
  Write-Output "      Your previous version was kept as *.bak - review the diff and reapply anything you"
  Write-Output "      want to keep (it will NOT be merged automatically):"
  foreach ($f in $script:backedUp) { Write-Output "        $f  (backup: $f.bak)" }
  Write-Output ""
} else {
  Write-Output "   agent definitions were already up to date - nothing backed up."
}

& (Join-Path $AIFLOW_HOME 'lib/apply.ps1')

$verFile = Join-Path $AIFLOW_HOME 'VERSION'
$newVer = if (Test-Path $verFile) { (Get-Content $verFile -TotalCount 1).Trim() } else { "0.0.0" }
$cfgObj = Get-Content $CFG -Raw | ConvertFrom-Json
if ($cfgObj.PSObject.Properties.Match('meta').Count -eq 0) {
  $cfgObj | Add-Member -NotePropertyName meta -NotePropertyValue ([pscustomobject]@{})
}
Set-JsonProperty $cfgObj.meta "aiflowVersion" $newVer
Write-JsonFile $CFG $cfgObj
Write-Output ">> project-update done. Stamped .aiflow/config.json meta.aiflowVersion=$newVer"
Write-Output "   Untouched, as always: .beads/ (issues), .claude/memory/* (project aim, conventions, codebase map)."

# ---- CI advice: helpers WE ship that no workflow of yours references (never rewrite a workflow) ----
# Iterates the TEMPLATE's helpers, not the project's: only aiflow-shipped scripts have a matching
# step to point at. -SimpleMatch so a filename is matched literally, not as a regex.
if ((Test-Path '.github/workflows') -and (Test-Path $ciScriptsSrc)) {
  $wfMissing = @()
  foreach ($h in (Get-ChildItem -Path $ciScriptsSrc -ErrorAction SilentlyContinue)) {
    $hit = Get-ChildItem -Path '.github/workflows' -File -Recurse -ErrorAction SilentlyContinue |
      Select-String -SimpleMatch -Pattern $h.Name -List -ErrorAction SilentlyContinue
    if (-not $hit) { $wfMissing += $h.Name }
  }
  if ($wfMissing.Count -gt 0) {
    Write-Output ""
    Write-Output "   note: .github/workflows/ is yours - project-update never rewrites it. These aiflow CI"
    Write-Output "   helpers are now present, but no workflow under .github/workflows/ references them:"
    foreach ($b in $wfMissing) { Write-Output "        .github/scripts/$b" }
    Write-Output ("   Copy the matching step from " + (Join-Path $TPL '.github/workflows/ci.yml') + " to enforce it.")
  }
}
