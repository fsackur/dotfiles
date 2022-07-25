function MergeAndDeploy
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [string]$PrTitle,

        [string]$PrBody,

        [string]$Head = (git name-rev HEAD --name-only),

        [string]$Base,

        [string]$Remote = 'upstream',

        [ValidateSet('Merge', 'Rebase', 'Squash')]
        [string]$MergeStrategy = 'merge',

        [switch]$ForceMerge,

        [securestring]$PSGalleryApiKey = (Read-Host -AsSecureString 'PSGallery API key')
    )

    $ErrorActionPreference = 'Stop'

    if (git status -s)
    {
        throw "You have uncommitted changes"
    }

    $null = Get-Command gh

    if (-not $Base)
    {
        $Result = git symbolic-ref refs/remotes/$Remote/HEAD --short 2>&1 | Out-String | foreach TrimEnd
        if (-not $?)
        {
            $Result | Write-Error
        }
        $Base = $Result -replace '.*/'
    }

    $Result = git rev-parse --show-toplevel 2>&1 | Out-String | foreach TrimEnd
    if (-not $?)
    {
        $Result | Write-Error
    }
    $RepoFolder = $Result | Resolve-Path

    $Module = $RepoFolder | ipmo -PassThru -Force -Verbose:$false

    $Result = git fetch --all --tags 2>&1 | Out-String | foreach TrimEnd
    if (-not $?)
    {
        $Result | Write-Error
    }
    $TagVersion = (git tag) -replace '^v' | foreach {[version]$_} | sort | select -Last 1

    if ($Module.Version -le $TagVersion)
    {
        throw "Module version is not higher than latest tag"
    }

    $Push = git push 2>&1 | Out-String | foreach TrimEnd
    if (-not $?)
    {
        $Push | Write-Error
    }

    $CreateArgs = (
        "pr",
        "create",
        "-B '$Base'",
        "-H '$Head'",
        "-t '$PrTitle'",
        $(if ($PrBody) {"-b '$PrBody'"} else {"--fill"})
    )

    (iex "gh $CreateArgs") *>&1 | Out-String | foreach TrimEnd | Tee-Object -Variable Create | Write-Verbose
    if (-not $?)
    {
        throw $Create
    }
    $PrNumber = ([uri]$Create).Segments[-1]


    $MergeArgs = (
        "pr",
        "merge",
        $PrNumber,
        "-$($MergeStrategy.Substring(0, 1).ToLower())",
        $(if ($ForceMerge) {"--admin"} else {"--auto"})
    )

    (iex "gh $MergeArgs") *>&1 | Out-String | foreach TrimEnd | Tee-Object -Variable Merge | Write-Verbose
    if ($Merge)
    {
        throw $Merge
    }


    $Result = git checkout $Base 2>&1 | Out-String | foreach TrimEnd
    if (-not $?)
    {
        $Result | Write-Error
    }

    try
    {
        $Result = git pull 2>&1 | Out-String | foreach TrimEnd
        if (-not $?)
        {
            $Result | Write-Error
        }

        $Result = git tag "v$($Module.Version)" 2>&1 | Out-String | foreach TrimEnd
        if (-not $?)
        {
            $Result | Write-Error
        }

        $Result = git push --tags 2>&1 | Out-String | foreach TrimEnd
        if (-not $?)
        {
            $Result | Write-Error
        }

        ipmo PowerShellGet -MinimumVersion 3.0.12 -Verbose:$false

        Publish-PSResource -Verbose -Repository PSGallery -ApiKey ($PSGalleryApiKey | ConvertTo-Plaintext) -Path $RepoFolder 6>&1 | Write-Verbose

        $Result = git branch -f $Head 2>&1 | Out-String | foreach TrimEnd
        if (-not $?)
        {
            $Result | Write-Error
        }
    }
    finally
    {
        $Result = git checkout - 2>&1 | Out-String | foreach TrimEnd
        if (-not $?)
        {
            $Result | Write-Error
        }
    }
}
