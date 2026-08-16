# aiflow project-update - refresh THIS project's aiflow-generated files from the installed
# templates, then re-apply config.
#
# Refreshed (mechanical, always safe to overwrite): .aiflow/*.sh+ps1, .claude/hooks/*.sh+ps1,
# docker/run.sh+ps1, .github/scripts/* (aiflow's CI helpers - not meant to be edited).
# Refreshed (agent definitions + git hooks - see backup rule below): AGENTS.md, CLAUDE.md,
# .github/copilot-instructions.md, .claude/agents/*.md, .claude/commands/*.md,
# .claude/skills/*/SKILL.md, .githooks/*, .aiflow/router-config.example.json.
# Config: .aiflow/config.json keeps every value you set; keys a NEWER release introduced are
# filled in from templates/.aiflow/config.defaults.json, and meta.aiflowVersion is stamped.
# Backup rule: if a refreshed agent-definition file already differs from the incoming template
# (i.e. you customised it, or it's genuinely changed upstream), the OLD file is renamed to
# "<file>.bak" (never deleted) before the new one is written, and reported at the end so you can
# diff/reapply your customisations. Identical files are overwritten silently (nothing lost).
# Never deleted: project-update only copies. A helper aiflow drops or renames stays in the
# project; it is REPORTED at the end of the run (for .aiflow/ and .claude/hooks/, which are
# aiflow-owned) and left in place, because the same file may be one you added yourself.
# NEVER touched: .beads/ (issues), .claude/memory/* (project aim, conventions, codebase map, ...),
# .github/workflows/* (yours to extend - see below), and .aiflow/config.json's own content (only
# meta.aiflowVersion is stamped at the end) - your project aim, task history, and learned memory
# always survive a project-update.
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
Write-Output ">> refreshing agent definitions + git hooks (customised files are kept as *.bak)..."
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
# The router example is a reference file a project copies to ~/.claude-code-router/config.json,
# so a stale one is worth refreshing - but it is also the obvious place to keep a tweaked sample,
# hence the .bak rule rather than the mechanical block above (aiflow-ver).
Update-WithBackup (Join-Path $TPL '.aiflow/router-config.example.json') '.aiflow/router-config.example.json'

# Git hooks are enforcement policy a project tunes - but they are also how a shipped check
# reaches an existing project at all (aiflow-1l4's frontmatter guard reached only NEW projects
# while these were excluded). So they follow the .bak rule like the agent definitions.
$gitHooksSrc = Join-Path $TPL '.githooks'
if (Test-Path $gitHooksSrc) {
  Get-ChildItem -Path $gitHooksSrc -File -ErrorAction SilentlyContinue | ForEach-Object {
    Update-WithBackup $_.FullName (Join-Path '.githooks' $_.Name)
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
  Write-Output "   agent definitions + git hooks were already up to date - nothing backed up."
}

& (Join-Path $AIFLOW_HOME 'lib/apply.ps1')

$verFile = Join-Path $AIFLOW_HOME 'VERSION'
$newVer = if (Test-Path $verFile) { (Get-Content $verFile -TotalCount 1).Trim() } else { "0.0.0" }
$cfgObj = Get-Content $CFG -Raw | ConvertFrom-Json

# ---- config defaults: add keys a newer release introduced, never touch existing values ----
# Only `init`/`change-settings` write config.json, so a key added by a release never reached an
# already-generated project (aiflow-vxy). The merge walks the defaults and only writes what the
# project does not already have, so an existing value always wins.
function Add-MissingDefaults($target, $defaults) {
  $added = 0
  foreach ($prop in $defaults.PSObject.Properties) {
    if ($prop.Name -eq '$comment') { continue }
    $has = $target.PSObject.Properties.Match($prop.Name).Count -gt 0
    if (-not $has) {
      $target | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value
      $added++
    } elseif ($prop.Value -is [PSCustomObject] -and $target.($prop.Name) -is [PSCustomObject]) {
      $added += Add-MissingDefaults $target.($prop.Name) $prop.Value
    }
  }
  return $added
}
$defaultsPath = Join-Path $TPL '.aiflow/config.defaults.json'
if (Test-Path $defaultsPath) {
  try {
    $defaults = Get-Content $defaultsPath -Raw | ConvertFrom-Json
    if ((Add-MissingDefaults $cfgObj $defaults) -gt 0) {
      Write-Output "   config.json: filled in defaults for keys this project did not have yet"
    }
  } catch {
    [Console]::Error.WriteLine("   ! could not merge config defaults - .aiflow/config.json left untouched")
  }
}

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

# ---- orphan advice: scripts in YOUR aiflow-owned directories that the templates no longer ship ----
# project-update copies, it never deletes - so a helper aiflow renamed or dropped would sit in the
# project forever, unmentioned (aiflow-400). Reported, never touched: the file may equally well be
# one you added. .github/scripts/ is deliberately NOT scanned - it is a conventional shared
# directory, so a project's own CI script there is normal and flagging it would be pure noise.
$orphans = @()
foreach ($d in @('.aiflow', '.claude/hooks')) {
  if (-not (Test-Path $d)) { continue }
  Get-ChildItem -Path $d -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -eq '.sh' -or $_.Extension -eq '.ps1' } |
    ForEach-Object {
      if (-not (Test-Path (Join-Path (Join-Path $TPL $d) $_.Name))) { $orphans += "$d/$($_.Name)" }
    }
}
if ($orphans.Count -gt 0) {
  Write-Output ""
  Write-Output "   note: these are in your project but aiflow no longer ships them - a helper removed"
  Write-Output "   upstream, or one of your own. Nothing was deleted; remove them yourself if unused:"
  foreach ($f in $orphans) { Write-Output "        $f" }
}
