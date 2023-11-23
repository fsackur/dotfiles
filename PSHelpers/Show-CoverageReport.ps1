function Show-CoverageReport
{
    <#
        .SYNOPSIS
        Shows an HTML test coverage report.

        .DESCRIPTION
        Uses the ReportGenerator tool to parse a coverage file from Pester and generate an HTML
        report.

        ReportGenerator will be installed if missing.

        Requires .NET SDK 5.0 or later. Tested with 7.0.0.

        .PARAMETER SourcePath
        The path to the containing folder.

        .PARAMETER Include
        Files to include. By default, all files in SourcePath are included.

        .PARAMETER ReportPath
        The path to a coverage file from Pester. Tested with CoverageGutters format.

        .PARAMETER OutputPath
        A folder to contain the generated report files.

        .OUTPUTS
        [void]

        .EXAMPLE
        Show-CoverageReport

        Generates a coverage report for the current folder, using .\coverage.xml.
    #>

    [CmdletBinding(
        SupportsShouldProcess,
        ConfirmImpact = 'Medium',
        HelpUri = 'https://pages.github.rackspace.com/windows-automation/RaxDev/functions/Show-CoverageReport'
    )]
    param
    (
        [Parameter()]
        [string]$SourcePath = '.',

        [Parameter()]
        [SupportsWildcards()]
        [string[]]$Include,

        [Parameter()]
        [string]$ReportPath = 'coverage.xml',

        [Parameter()]
        [string]$OutputPath = 'CoverageReport'
    )

    $ReportType = 'Html'

    $SourcePath = $SourcePath | Resolve-Path -ErrorAction Stop
    Push-Location $SourcePath -ErrorAction Stop
    try
    {
        if ($Include)
        {
            $Include = $Include | Resolve-Path -ErrorAction Stop
            $Include = $Include -replace '^', '+'
        }

        $ReportPath = $ReportPath | Resolve-Path -ErrorAction Stop

        try
        {
            $OutputPath = $OutputPath | Resolve-Path -ErrorAction Stop
        }
        catch
        {
            $OutputPath = New-Item $OutputPath -ItemType Directory -Force -ErrorAction Stop
        }
    }
    finally
    {
        Pop-Location
    }

    $PackageParams = @{
        Name           = 'ReportGenerator'
        MinimumVersion = [version]'4.8.13'
        ErrorAction    = 'Stop'
    }

    try
    {
        $null = Get-Command dotnet -ErrorAction Stop
        $DotNetVersion = [version]((dotnet --version) -replace '-.*')
        if ($DotNetVersion -lt ([version]'5.0'))
        {
            throw "DotNet version $DotNetVersion is below 5.0"
        }
    }
    catch
    {
        $_.ErrorDetails = "DotNet of version 5.0 or above is not installed or not on the path. Install the .NET SDK for .NET 5.0."
        Write-Error -ErrorRecord $_ -ErrorAction Stop
    }

    try
    {
        $Package = Get-Package @PackageParams
    }
    catch
    {
        if ($_ -match 'No package found')
        {
            if ($PSCmdlet.ShouldProcess($PackageName, "Install-Package"))
            {
                Install-Package @PackageParams -Force -ForceBootstrap -Scope CurrentUser
                $Package = Get-Package @PackageParams
            }
            else
            {
                Write-Error "Package $($PackageParams.Name) with minimum version $($PackageParams.MinimumVersion) is not installed." -ErrorAction Stop
            }
        }
        else
        {
            Write-Error -ErrorRecord $_ -ErrorAction Stop
        }
    }

    $PackagePath = $Package.Source |
        Split-Path |
        Join-Path -ChildPath tools |
        Join-Path -ChildPath net5.0 |
        Join-Path -ChildPath "$($PackageParams.Name).dll"

    # Interactive param generator: https://reportgenerator.io/usage.html
    $ReportArgs = @(
        "-sourcedirs:$SourcePath",
        "-filefilters:$($Include -join ';')",
        "-reports:$ReportPath",
        "-targetdir:$OutputPath",
        "-reporttypes:$($ReportType -join ';')"
    ) -notmatch ':$' # remove empty args

    dotnet $PackagePath @ReportArgs | Write-Verbose

    if ($?)
    {
        Join-Path $OutputPath index.htm | Invoke-Item
    }
}
