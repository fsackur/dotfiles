
$Global:IS_PS_CORE = $PSVersionTable.PSVersion.Major -ge 6
$Global:IS_VSCODE = (
    (-not $IS_PS_CORE -and (Get-Process -Id (Get-CimInstance Win32_Process -Filter "ProcessId = $PID").ParentProcessId).ProcessName -match '^Code( - Insiders)?$') -or
    ($IS_PS_CORE -and (Get-Process -Id $PId).Parent.ProcessName -match '^Code( - Insiders)?$')
)
$Global:IS_ISE     = $Host.Name -eq 'Windows PowerShell ISE Host'
$Global:IS_WSL     = [bool]$env:WSL_DISTRO_NAME
$Global:IS_WINDOWS = [Environment]::OSVersion.Platform -match 'Win'
$Global:IS_LINUX   = [Environment]::OSVersion.Platform -match 'Unix'

if ($Global:IS_WINDOWS)
{
    $Global:XDG_CONFIG_HOME = Split-Path $PSScriptRoot
}

$env:EDITOR = "code --wait"
