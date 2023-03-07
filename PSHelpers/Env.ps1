
$Global:IS_ISE          = $Host.Name -eq 'Windows PowerShell ISE Host'
$Global:IS_WSL          = [bool]$env:WSL_DISTRO_NAME
$Global:IS_PS_CORE      = $PSVersionTable.PSVersion.Major -ge 6
if (-not $IS_PS_CORE)
{
    $Global:IsWindows = [Environment]::OSVersion.Platform -match 'Win'
}
$Global:IS_RASPBERRY_PI = $IsLinux -and (Test-Path /etc/os-release) -and (gc /etc/os-release) -match 'raspbian'

if ($Global:IsWindows)
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

$Disapproval = 'ಠ_ಠ'
