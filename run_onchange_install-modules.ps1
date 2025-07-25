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
    @{ModuleName = "PSScriptAnalyzer"; ModuleVersion = "1.23.0"},
    @{ModuleName = "InvokeBuild"; ModuleVersion = "5.12.1"},
    @{ModuleName = "Microsoft.PowerShell.UnixTabCompletion"; ModuleVersion = "0.5.0"},
    @{ModuleName = "psyml"; ModuleVersion = "1.0.0"},
    @{ModuleName = "PSFzf"; ModuleVersion = "2.6.1"},
    @{ModuleName = "Microsoft.PowerShell.SecretManagement"; ModuleVersion = "1.1.2"},
    @{ModuleName = "SecretManagement.Warden"; ModuleVersion = "1.1.5"}
)

$ToInstall = $Required | ? {-not (Get-Module -ListAvailable -FullyQualifiedName $_)}
if (-not $ToInstall)
{
    return
}

$Commands = @()

if ($ToInstall | ? Name -eq 'PSReadLine')
{
    if (Find-Module PSReadLine -MinimumVersion 2.4.0 -ErrorAction Ignore)
    {
        throw "PSReadLine 2.4.0 is available; update chezmoi to migrate off beta."
    }

    $Commands += "Install-Module PSReadLine -AllowPrerelease"
    $ToInstall = $ToInstall | ? Name -ne 'PSReadLine'
}

$Commands += $ToInstall |
    ForEach-Object {
        "Install-Module $($_.Name) -MinimumVersion $($_.Version)"
    }

$Commands = $Commands | ForEach-Object {"$_ -Scope AllUsers -Force -AcceptLicense"}

sudo pwsh -NoProfile -c ($Commands -join '; ')
