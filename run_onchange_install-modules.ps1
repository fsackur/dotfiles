#! /usr/bin/pwsh

$ErrorActionPreference = 'Stop'

[Microsoft.PowerShell.Commands.ModuleSpecification[]]$Required = @(
    @{ModuleName = "PSReadLine"; ModuleVersion = "2.4.0"},
    @{ModuleName = "PackageManagement"; ModuleVersion = "1.4.8.1"},
    @{ModuleName = "PowerShellGet"; ModuleVersion = "2.2.5"},
    @{ModuleName = "posh-git"; ModuleVersion = "1.1.0"},
    @{ModuleName = "Metadata"; ModuleVersion = "1.5.7"},
    @{ModuleName = "Configuration"; ModuleVersion = "1.6.0"},
    @{ModuleName = "poke"; ModuleVersion = "1.1.2"},
    @{ModuleName = "Pester"; ModuleVersion = "5.6.1"},
    @{ModuleName = "Microsoft.PowerShell.UnixTabCompletion"; ModuleVersion = "0.5.0"},
    @{ModuleName = "psyml"; ModuleVersion = "1.0.0"},
    @{ModuleName = "PSFzf"; ModuleVersion = "2.6.1"}
)

$ToInstall = $Required | ? {-not (gmo -ListAvailable -FullyQualifiedName $_)}
if (-not $ToInstall)
{
    return
}

$Commands = @()
# delete when 2.4.0 finally hits GA
if ($ToInstall | ? Name -eq 'PSReadLine')
{
    $Commands += "Install-Module PSReadLine -AllowPrerelease -Force"
    $ToInstall = $ToInstall | ? Name -ne 'PSReadLine'
}

$Commands += $ToInstall |
    ForEach-Object {
        "Install-Module $($_.Name) -MinimumVersion $($_.Version) -Scope AllUsers -Force -AcceptLicense"
    }

sudo pwsh -NoProfile -c ($Commands -join '; ')
