function Git-Add
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$File = '*'
    )
    git add $File; git status -v; git status
}
Register-ArgumentCompleter -CommandName Git-Add -ParameterName File -ScriptBlock {
    param
    (
        $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters
    )
    @(git status -s) -replace '^...' -like "*$wordToComplete*"
}
Set-Alias a Git-Add

function Git-Commit
{
    [CmdletBinding()]
    param
    (
	    [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter(ValueFromRemainingArguments)]
        [string[]]$MessageParts
    )
    if ($MessageParts) {$Message = "$Message $MessageParts"}
    git commit -m "`"$Message`""
}
Set-Alias c Git-Commit

function Git-Fixup
{
    [CmdletBinding()]
    param
    (
	    [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter(ValueFromRemainingArguments)]
        [string[]]$MessageParts
    )
    if ($MessageParts) {$Message = "$Message $MessageParts"}
    git commit -m "`"fixup! $Message`""
}
Register-ArgumentCompleter -CommandName Git-Fixup -ParameterName Message -ScriptBlock {
    param
    (
        $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters
    )

    @((ggl -InformationAction SilentlyContinue).Summary) -like "*$wordToComplete*"
}
Set-Alias f Git-Fixup

function Git-Branch
{
    param
    (
        [Parameter(Mandatory, Position=0)]
        [ValidateNotNullOrEmpty()]
        [string]$Branch
    )

    $chbr = git checkout $Branch *>&1

    if ($chbr.ToString() -match 'did not match any file')
    {
        Write-Host -ForegroundColor DarkYellow 'Creating new branch...'
        $newbr = git checkout -b $Branch *>&1
        $pushbr = git push -u origin $Branch *>&1
        if (-not ($pushbr | Out-String) -match 'set up to track remote branch')
        {
            $pushbr
        }
    }
}
Set-Alias b Git-Branch

function Git-Checkout
{
    param
    (
        [Parameter(Mandatory, Position = 0)]
        [string]$Branch
    )

    git checkout $Branch
    git checkout -b ($Branch -replace '^.*/')
    git branch -u $Branch
}
Register-ArgumentCompleter -CommandName Git-Checkout -ParameterName Branch -ScriptBlock {
    param
    (
        $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters
    )

    @((git branch -a) -match '^  remotes/' -replace '^  remotes/') -like "$wordToComplete*"
}
Set-Alias gco Git-Checkout

function Git-AddRemote
{
    param
    (
        [Parameter(Mandatory)]
        [string]$Owner
    )

    $Owner = $Owner.Trim()

    $Origin = git remote -v | sls origin | select -First 1
    $OriginUrl = $Origin -replace '^origin\s+' -replace '\s.*'
    $NewUrl = $OriginUrl -replace [regex]::Escape($env:USERNAME), $Owner

    git remote add $Owner $NewUrl
    git fetch $Owner
}

function Clear-DeletedRemoteBranches
{
    (git branch -vv |sls ': gone') -replace '^ *' -replace ' .*' | %{git branch -D $_}
}






function Get-GitLog
{
    <#
        .SYNOPSIS
        Gets the git log.

        .DESCRIPTION
        Gets the git log. By default, gets commits since the last merge.

        .PARAMETER SinceLastPRMerge
        Specifies to fetch commits as far back as the last merged PR or the last commit by
        'whamapi-cicd-svc'.

        .PARAMETER Commits
        Specify how many commits to retrieve.

        .PARAMETER Remote
        Specify the remote name of the ref from which to fetch commits. Defaults to the local clone.

        .PARAMETER Branch
        Specify the branch name of the ref from which to fetch commits. Defaults to the current branch.

        .PARAMETER Weeks
        Specify how many weeks to look back. Defaults to 8.

        .PARAMETER SortDescending
        Specifies to return commits in chronological order.

        .OUTPUTS
        [psobject]

        .EXAMPLE
        ggl

            Count: 5

        Id      Author         UpdatedAt      Summary
        --      ------         ---------      -------
        23cdb63 Freddie Sackur 26 seconds ago Version increment 1.2.2.0 =>1.2.3.0
        efa2bbd Freddie Sackur 2 minutes ago  Colourised Get-GitLog output
        e9b62ae Freddie Sackur 31 minutes ago Added some usability tweaks to Get-GitLog
        8b912e7 Freddie Sackur 81 minutes ago New function Get-GitLog
        34c2df5 Freddie Sackur 82 minutes ago Tidy

        Gets the git log since the last merge.
    #>
    [CmdletBinding(DefaultParameterSetName = 'SinceLastPRMerge')]
    [OutputType([psobject])]
    param
    (
        [Parameter(ParameterSetName = 'SinceLastPRMerge')]
        [switch]$SinceLastPRMerge,

        [Parameter(ParameterSetName = 'Default')]
        [Parameter(Position = 0)]
        [int]$Commits = 30,

        [Parameter()]
        [string]$Remote,

        [Parameter()]
        [string]$Branch,

        [Parameter(ParameterSetName = 'Default')]
        [Parameter()]
        [int]$Weeks = 8,

        [Parameter()]
        [switch]$SortDescending
    )

    $OutputProperties = @(
        'Id',
        'Author',
        'UpdatedAt',
        'Summary'
    )

    $Commits = [Math]::Abs($Commits)

    if (-not $PSBoundParameters.ContainsKey('InformationAction'))
    {
        $InformationPreference = 'Continue'
    }

    $ArgumentList = @(
        "log",
        '--pretty=format:"%h;%an;%ar;%s"'
        "-$Commits"
    )

    if ($PSBoundParameters.ContainsKey('Remote') -or $PSBoundParameters.ContainsKey('Branch'))
    {
        if (-not $Remote) {$Remote = 'origin'}

        $Ref = $Remote, $Branch -join '/'
        $ArgumentList += $Ref

        if ($PSVersionTable.PSVersion.Major -ge 5)
        {
            Write-Information "$([Environment]::NewLine)    Ref: $Ref"
        }
    }


    if ($PSBoundParameters.ContainsKey('Weeks'))
    {
        $ArgumentList += "--since=$Weeks.weeks"
    }




    $CommitLines = & git $ArgumentList



    if ($PSCmdlet.ParameterSetName -eq 'SinceLastPRMerge')
    {
        $CommitLines = $CommitLines.Where({$_ -match 'whamapi-cicd-svc|;Merge pull request'}, 'Until')
    }


    $Output = $CommitLines | ForEach-Object {
        $Values = $_ -split ';', 4
        $Commit = [pscustomobject]@{
            $OutputProperties[0] = $Values[0]
            $OutputProperties[1] = $Values[1]
            $OutputProperties[2] = $Values[2]
            $OutputProperties[3] = $Values[3]
        }
        $Commit.PSTypeNames.Insert(0, 'GitCommit')
        $Commit
    }


    if ($SortDescending)
    {
        [array]::Reverse($Output)
    }

    $Output


    if ($PSVersionTable.PSVersion.Major -ge 5)
    {
        Write-Information "$([string][char]8 * 4)    Count: $($Output.Count)`n"
    }
}
Set-Alias ggl Get-GitLog
