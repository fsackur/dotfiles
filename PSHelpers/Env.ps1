
$Global:IS_ISE     = $Host.Name -eq 'Windows PowerShell ISE Host'
$Global:IS_WSL     = [bool]$env:WSL_DISTRO_NAME
$Global:IS_WINDOWS = [Environment]::OSVersion.Platform -match 'Win'
$Global:IS_LINUX   = [Environment]::OSVersion.Platform -match 'Unix'
$Global:IS_PS_CORE = $PSVersionTable.PSVersion.Major -ge 6

$ParentProcess = if ($IS_PS_CORE)
{
    (Get-Process -Id $PId).Parent
}
else
{
    Get-Process -Id (Get-CimInstance Win32_Process -Filter "ProcessId = $PID").ParentProcessId
}
$Global:IS_VSCODE = $ParentProcess.ProcessName -match '^node|(Code( - Insiders)?)$'

if ($Global:IS_WINDOWS)
{
    $Global:XDG_CONFIG_HOME = Split-Path $PSScriptRoot
}

$env:EDITOR = "code --wait"

# Not always correct - may need to fix later
$Global:MODULE_PATH = $env:PSModulePath -split [System.IO.Path]::PathSeparator -match [regex]::Escape($HOME) | Select-Object -First 1
