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

        [Parameter(ValueFromPipeline)]
        [SupportsWildcards()]
        [string[]]$Filter,

        [switch]$Regex,

        [switch]$AllowPrerelease
    )

    begin
    {
        # Get all releases and then get the first matching release. Necessary because a project's "latest"
        # release according to Github might be of a different product or component than the one you're
        # looking for. Also, Github's 'latest' release doesn't include prereleases.
        $Releases = Invoke-RestMethod -Method Get -Uri "https://api.github.com/repos/$Org/$Repo/releases"

        $Latest = $Releases |
            Where-Object {$_.tag_name -like $Tag} |
            Where-Object {$AllowPrerelease -or -not $_.prerelease} |
            Select-Object -First 1
    }

    process
    {
        $Assets = if ($Regex)
        {
            $Pattern = $Filter -join '|'
            $Latest.assets | Where-Object {$_.name -match $Pattern}
        }
        elseif ($Filter)
        {
            foreach ($Filter in $Filter)
            {
                $Latest.assets | Where-Object {$_.name -like $Filter}
            }
        }
        else
        {
            $Latest.assets
        }

        $Assets.browser_download_url
    }
}

function Install-WinGet
{
    $msStoreDownloadAPIURL = 'https://store.rg-adguard.net/api/GetFiles'
    $msWinGetStoreURL = 'https://www.microsoft.com/en-us/p/app-installer/9nblggh4nns1'
    $architecture = 'x64'
    $appxPackageName = 'Microsoft.DesktopAppInstaller'
    $msWinGetMSIXBundlePath = ".\$appxPackageName.msixbundle"
    $msWinGetLicensePath = ".\$appxPackageName.license.xml"
    $msVCLibPattern = "*Microsoft.VCLibs*UWPDesktop*$architecture*appx*"
    $msVCLibDownloadPath = '.\Microsoft.VCLibs.UWPDesktop.appx'
    $msUIXamlPattern = "*Microsoft.UI.Xaml*$architecture*appx*"
    $msUIXamlDownloadPath = '.\Microsoft.UI.Xaml.appx'

    $MsixUri = Find-GithubLatestReleaseAssetUri microsoft winget-cli -Asset *.msixbundle
    $LicenseUri = Find-GithubLatestReleaseAssetUri microsoft winget-cli -Asset *License*.xml
    iwr $MsixUri -OutFile $msWinGetMSIXBundlePath
    iwr $LicenseUri -OutFile $msWinGetLicensePath


    $Response = Invoke-WebRequest -Uri $msStoreDownloadAPIURL -Method Post -Body "type=url&url=$msWinGetStoreURL&ring=Retail&lang=en-US"
    $Uri = $Response.Links | ? OuterHtml -Like $msVCLibPattern | Select-Object -First 1 -ExpandProperty href
    iwr $Uri -OutFile $msVCLibDownloadPath
    $Uri = $Response.Links | ? OuterHtml -Like $msUIXamlPattern | Select-Object -First 1 -ExpandProperty href
    iwr $Uri -OutFile $msUIXamlDownloadPath
}

function Install-NerdFont
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]]$Font
    )

    end
    {
        if ($MyInvocation.ExpectingInput)
        {
            $Font = $Input
        }

        $Font = $Font | Select-Object -Unique | % {"$_.zip"}

        [uri[]]$FontUris = Find-GithubLatestReleaseAssetUri ryanoasis nerd-fonts -Filter $Font

        $Folders = $FontUris | % {
            $FontName = $_.Segments[-1] -replace '\.zip$'
            $ZipPath = "$env:TEMP\$FontName.zip"
            $Folder = "$env:TEMP\$FontName"

            iwr $_ -OutFile $ZipPath
            Expand-Archive -Path $ZipPath -DestinationPath $Folder -Force
            Remove-Item $ZipPath -Force

            gci $Folder | ? Extension -notmatch '^\.[ot]tf$' | del
            $Folder
        }

        if (-not $Folders)
        {
            throw "No fonts found."
        }

        $Shell = New-Object -ComObject Shell.Application
        $FontsFolder = $Shell.NameSpace(0x14)

        # https://learn.microsoft.com/en-us/windows/win32/shell/folder-copyhere#parameters
        $Quiet = 0x14
        $YesToAll = 0x10

        $Folders | % {
            $Folder = $Shell.NameSpace($_)
            $FontsFolder.CopyHere($Folder.Items(), $YesToAll)
        }

        $Folders | del -Recurse -Force
    }
}

$FontNames = 'Meslo', 'Hack', 'FiraCode'
# $FontNames | Install-NerdFont
