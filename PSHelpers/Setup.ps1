$PackageNames = @{
    Module = @(
        'PackageManagement',
        'PowerShellGet',
        'posh-git',
        'Metadata',
        'Configuration',
        'poke',
        'Pester'
    )
    winget = @(
        'Microsoft.PowerShell',
        'Microsoft.WindowsTerminal',
        'Git.Git',
        'Microsoft.VisualStudioCode',
        'Starship.Starship',
        'Microsoft.AzureCLI',
        'Microsoft.OpenSSH.Beta',
        'GitHub.cli',
        'Google.Chrome',
        'Mozilla.Firefox',
        'Telerik.Fiddler.Classic',
        'NpcapInst',
        'WiresharkFoundation.Wireshark',
        'Python.Python.3.11',
        'Microsoft.DotNet.SDK.7',
        'JAMSoftware.TreeSize.Free'
    )
}

function Initialize-Computer
{
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param
    (
        [Parameter(Mandatory)]
        [ValidateSet('Module', 'WinGet')]
        [string]$Type,

        [switch]$Force
    )

    if ($Force)
    {
        $ConfirmPreference = 'None'
    }

    $Candidates = $PackageNames[$Type]

    $ToInstall = $Candidates | Where-Object {$PSCmdlet.ShouldProcess($_, 'Install')}

    if ($Type -eq 'Module')
    {
        $PMgmt = Import-Module -PassThru PackageManagement -ErrorAction Stop
        $PSGet = Import-Module -PassThru PowerShellGet -ErrorAction Stop

        if ($ToInstall -and $PMgmt.Version -lt ([version]'1.4'))
        {
            if ('PackageManagement' -in $ToInstall)
            {
                Install-Module PackageManagement -AllowClobber -Force -ErrorAction Stop
                $Install = @($Install) -ne 'PackageManagement'
            }
            else
            {
                throw "Must update PackageManagement first."
            }
        }

        if ($ToInstall -and $PSGet.Version -lt ([version]'2.0'))
        {
            if ('PowerShellGet' -in $ToInstall)
            {
                Install-Module PowerShellGet -AllowClobber -Force -ErrorAction Stop
                $Install = @($Install) -ne 'PowerShellGet'
            }
            else
            {
                throw "Must update PowerShellGet first."
            }
        }

        if (-not $ToInstall) {return}

        $InstallParams = @{
            PassThru     = $true
            Force        = $true
            AllowClobber = $true
            Scope        = 'CurrentUser'
        }

        Install-Module @InstallParams $ToInstall

    }
    elseif ($Type -eq 'WinGet')
    {
        $ToInstall | ForEach-Object {
            winget install $_
        }
    }
}

function Find-GithubLatestReleaseAssetUri
{
    [OutputType([uri[]])]
    [CmdletBinding(DefaultParameterSetName = 'Default', PositionalBinding = $false)]
    param
    (
        [Parameter(Mandatory, Position = 0)]
        [Alias('User')]
        [string]$Org,

        [Parameter(Mandatory, Position = 1)]
        [string]$Repo,

        [SupportsWildcards()]
        [string]$Tag = '*',

        [SupportsWildcards()]
        [string[]]$Filter,

        [switch]$Regex,

        [switch]$AllowPrerelease
    )

    # Get all releases and then get the first matching release. Necessary because a project's "latest"
    # release according to Github might be of a different product or component than the one you're
    # looking for. Also, Github's 'latest' release doesn't include prereleases.
    $Releases = Invoke-RestMethod -Method Get -Uri "https://api.github.com/repos/$Org/$Repo/releases"

    $Latest = $Releases |
        Where-Object {$_.tag_name -like $Tag} |
        Where-Object {$AllowPrerelease -or -not $_.prerelease} |
        Select-Object -First 1

    $AssetFilter = if ($Regex)
    {
        {$_ -match $Filter}
    }
    elseif ($Filter)
    {
        {$_ -like $Filter}
    }
    else
    {
        {$true}
    }
    $Filters = $Filter

    $Assets = $Latest.assets |
        Where-Object {
            $AssetObject = $_
            $Filters | ForEach-Object {
                $Filter = $_
                $AssetObject | Where-Object $AssetFilter
            }
        }

    $Assets.browser_download_url
}
