
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


$DirSep = [System.IO.Path]::DirectorySeparatorChar
$PathSep = [System.IO.Path]::PathSeparator
$PSModulePath = $env:PSModulePath -split $PathSep
$Global:MODULE_PATH = @($PSModulePath) -like "$HOME$DirSep*$DirSep`Modules" | Select-Object -First 1
if ($MODULE_PATH)
{
    $GitModulePath = $MODULE_PATH -replace 'Modules$', 'GitModules'
    if ($GitModulePath -notin $PSModulePath)
    {
        $env:PSModulePath = $GitModulePath, $env:PSModulePath -join $PathSep
    }
}

$env:CDPATH = ('.', $HOME, $GitModulePath, $MODULE_PATH) -match '.' -join $PathSep
