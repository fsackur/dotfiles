
$Global:IS_VSCODE = (
    (
        $PSVersionTable.PSVersion.Major -le 5 -and
        (Get-Process -Id (Get-CimInstance Win32_Process -Filter "ProcessId = $PID").ParentProcessId).ProcessName -match '^Code( - Insiders)?$'
    ) -or
    (
        $PSVersionTable.PSVersion.Major -ge 6 -and
        (Get-Process -Id $PId).Parent.ProcessName -match '^Code( - Insiders)?$'
    )
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
