function Get-PSDefaultModulePath
{
    <#
        .LINK
        https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_psmodulepath
    #>

    [CmdletBinding()]
    param
    (
        [ValidateSet('CurrentUser', 'AllUsers', 'Machine')]
        [string]$Scope = 'CurrentUser',

        [switch]$PowerShellGetV2CompatibilityMode
    )

    $AllUsersConfig = $CurrentUserConfig = $null
    $IsPSCore = $PSVersionTable.PSEdition -eq 'Core'
    if ($IsPSCore -and -not $PowerShellGetV2CompatibilityMode)
    {
        # https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_powershell_config
        if ($Scope -eq 'AllUsers')
        {
            $AllUsersConfig = $PSHOME |
                Join-Path -ChildPath powershell.config.json |
                Resolve-Path -ErrorAction SilentlyContinue |
                Where-Object Path |
                Get-Content |
                ConvertFrom-Json
        }

        if ($Scope -eq 'CurrentUser')
        {
            $CurrentUserConfig = $PROFILE.CurrentUserCurrentHost |
                Split-Path |
                Join-Path -ChildPath powershell.config.json |
                Resolve-Path -ErrorAction SilentlyContinue |
                Where-Object Path |
                Get-Content |
                ConvertFrom-Json
        }
    }

    switch ($Scope)
    {
        'CurrentUser'
        {
            if ($CurrentUserConfig.PSModulePath)
            {
                $CurrentUserConfig.PSModulePath
            }
            elseif ([Environment]::OSVersion.Platform -match 'Win')
            {
                "$HOME\Documents\PowerShell\Modules"
            }
            elseif($env:XDG_DATA_HOME)
            {
                "$env:XDG_DATA_HOME/powershell/Modules"
            }
            else
            {
                "$HOME/.local/share/powershell/Modules"
            }
        }

        'AllUsers'
        {
            if ($AllUsersConfig.PSModulePath)
            {
                $AllUsersConfig.PSModulePath
            }
            elseif ([Environment]::OSVersion.Platform -match 'Win')
            {
                "$env:ProgramFiles\PowerShell\Modules"
            }
            else
            {
                "/usr/local/share/powershell/Modules"
            }
        }

        'Machine'
        {
            Join-Path $PSHOME Modules
        }
    }
}

function Link-Module
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName', 'ModuleBase', 'InstalledLocation')]  # Support piping from gci, gmo and Get-InstalledModule
        [string]$Path,

        [ValidateSet('AllUsers', 'CurrentUser')]
        [string]$Scope = 'CurrentUser'
    )

    begin
    {
        $PSModulePath = Get-PSDefaultModulePath -Scope $Scope
    }

    process
    {
        $Path = Resolve-Path $Path -ErrorAction Stop

        if (Test-Path $Path -PathType Leaf)
        {
            $Path = Split-Path $Path
        }

        $PathVersion = (Split-Path $Path) -as [version]
        $UnversionedPath = if ($PathVersion) {Split-Path $Path} else {$Path}
        $Name = Split-Path $UnversionedPath -Leaf

        $LinkModuleBase = Join-Path $PSModulePath $Name
        New-Link $LinkModuleBase $Path
    }
}
