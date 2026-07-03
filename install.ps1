# Install aiflow on Windows: create aiflow.cmd shim + add bin dir to user PATH.
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$bin  = Join-Path $here 'bin'

# cmd shim so 'aiflow' works from cmd.exe and PowerShell
$shim = Join-Path $bin 'aiflow.cmd'
@"
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0aiflow.ps1" %*
"@ | Set-Content -Path $shim -Encoding ascii

# add bin to user PATH if missing
$userPath = [Environment]::GetEnvironmentVariable('Path','User')
if ($userPath -notlike "*$bin*") {
  [Environment]::SetEnvironmentVariable('Path', "$userPath;$bin", 'User')
  Write-Output "Added to user PATH: $bin"
} else {
  Write-Output "Already on user PATH: $bin"
}

# make 'aiflow' work in THIS session immediately (no restart needed for the shell that ran install)
if ($env:Path -notlike "*$bin*") {
  $env:Path = "$env:Path;$bin"
}

# broadcast WM_SETTINGCHANGE so newly launched processes pick up the PATH without a reboot
if (-not ('Win32.NativeMethods' -as [type])) {
  Add-Type -Namespace Win32 -Name NativeMethods -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll", SetLastError=true, CharSet=System.Runtime.InteropServices.CharSet.Auto)]
public static extern System.IntPtr SendMessageTimeout(System.IntPtr hWnd, uint Msg, System.UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out System.UIntPtr lpdwResult);
'@
}
$HWND_BROADCAST = [System.IntPtr]0xffff
$WM_SETTINGCHANGE = 0x1A
$result = [System.UIntPtr]::Zero
[void][Win32.NativeMethods]::SendMessageTimeout($HWND_BROADCAST, $WM_SETTINGCHANGE, [System.UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$result)

Write-Output ""
Write-Output "Installed. 'aiflow' is available NOW in this window."

# ---- optional prerequisites (ask once, at install time) ----
function Test-Have($name) { return [bool](Get-Command $name -ErrorAction SilentlyContinue) }
function Read-YN($prompt, $default) {
  $a = Read-Host "  $prompt (y/n) [$default]"
  if ([string]::IsNullOrWhiteSpace($a)) { $a = $default }
  return ($a -match '^[Yy]')
}
function Install-Pkg($wingetId, $scoopName) {
  if (Test-Have winget) { winget install --id $wingetId -e --accept-source-agreements --accept-package-agreements }
  elseif (Test-Have scoop) { scoop install $scoopName }
  else { Write-Output "  ! install $wingetId / $scoopName manually" }
}
Write-Output ""
Write-Output "Optional prerequisites (so 'aiflow init' later only asks which Ollama models to pull):"
if (-not (Test-Have git)) { if (Read-YN 'Install git?' 'y') { Install-Pkg 'Git.Git' 'git' } } else { Write-Output "  git already present" }
if (-not (Test-Have svn)) { if (Read-YN 'Install Subversion (svn)?' 'n') { Install-Pkg 'TortoiseSVN.TortoiseSVN' 'svn' } } else { Write-Output "  svn already present" }
if (-not (Test-Have ollama)) { if (Read-YN 'Install Ollama (local models)?' 'n') { Install-Pkg 'Ollama.Ollama' 'ollama' } } else { Write-Output "  ollama already present" }

Write-Output ""
Write-Output "IMPORTANT for VS Code: the integrated terminal inherits PATH from VS Code"
Write-Output "at launch, so a new terminal TAB is not enough. Fully restart VS Code"
Write-Output "(or run the Command Palette: 'Developer: Reload Window') to pick up 'aiflow'."
Write-Output "Plain cmd/PowerShell windows: just open a new one."
Write-Output ""
Write-Output "Then:"
Write-Output "  aiflow doctor              # see what's present"
Write-Output "  aiflow install-deps --all  # install the rest of the toolchain"
Write-Output "  aiflow init                # bootstrap a project (pick Ollama models, remote host + MCP, etc.)"
