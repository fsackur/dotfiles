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
        [string[]]$Asset = '*',

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

    $Assets = $Latest.assets |
        Where-Object {
            $_Asset = $_
            $Asset | Where-Object {$_Asset.name -like $_}
        }

    $Assets.browser_download_url
}
