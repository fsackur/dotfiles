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

    @((ggl -InformationAction SilentlyContinue -Commits 80).Summary) -like "*$wordToComplete*"
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
        [string]$Name,

        [Parameter(Mandatory, Position = 1)]
        [string]$Owner
    )

    $Owner = $Owner.Trim()

    if (-not $Name) {$Name = $Owner}

    $Origin = git remote -v | sls origin | select -First 1
    [uri]$OriginUrl = $Origin -replace '^origin\s+' -replace '\s.*'
    $BaseUrl = $OriginUrl -replace [regex]::Escape($OriginUrl.LocalPath)
    $NewUrl = $BaseUrl, $Owner, $OriginUrl.Segments[-1] -join '/'

    git remote add $Name $NewUrl
    git fetch $Name
}

function Clear-DeletedRemoteBranches
{
    (git branch -vv |sls ': gone') -replace '^ *' -replace ' .*' | %{git branch -D $_}
}

function Git-Reset
{
    [CmdletBinding(DefaultParameterSetName = 'Soft')]
    param
    (
        [Parameter(ParameterSetName = 'Hard')]
        [switch]$Hard,

        [Parameter(ParameterSetName = 'Soft')]
        [switch]$Soft,

        [Parameter(Position = 0)]
        [ValidateRange(0, 2147483647)]
        [int]$Commits = 0
    )

    git add --all

    $args = @()
    if ($PSCmdlet.ParameterSetName -eq 'Hard') {$args += '--hard'}
    git reset HEAD~$Commits $args
}
Set-Alias rst Git-Reset



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
        [Parameter(ParameterSetName = 'FromRef')]
        [string]$FromRef,

        [Parameter(ParameterSetName = 'SinceLastPRMerge')]
        [switch]$SinceLastPRMerge,

        [Parameter(ParameterSetName = 'FromRef')]
        [Parameter(ParameterSetName = 'Default')]
        [Parameter(Position = 0)]
        [int]$Count = 30,

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

    if (-not $PSBoundParameters.ContainsKey('InformationAction'))
    {
        $InformationPreference = 'Continue'
    }

    $ArgumentList = @(
        "log",
        '--pretty=format:"%h;%an;%ar;%s"'
    )

    if ($PSCmdlet.ParameterSetName -eq 'Default')
    {
        $Count = [Math]::Abs($Count)
        $ArgumentList += "-$Count"
    }

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

    if ($PSCmdlet.ParameterSetName -eq 'FromRef')
    {
        $ArgumentList += "HEAD"
        $ArgumentList += "^$FromRef"
        $ArgumentList += '--ancestry-path'
    }


    $CommitLines = & git $ArgumentList


    if ($PSCmdlet.ParameterSetName -eq 'FromRef')
    {
        $CommitLines = $CommitLines | Select-Object -Last $Count
    }

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
        if ($PSCmdlet.ParameterSetName -eq 'FromRef')
        {
            $Message = "First $($Output.Count) commits starting from $FromRef"
        }
        else
        {
            $Message = "Count: $($Output.Count)"
        }
        Write-Information "$([string][char]8 * 4)    $Message`n"
    }
}
Set-Alias ggl Get-GitLog


function CherryPick-Interactive
{
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param
    (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Id', 'CommitId', 'SHA', 'Hash', 'Ref')]
        [string]$Commit
        # [int]$Commit
    )

    begin
    {
        $StartingCommit = (git show -s --oneline HEAD) -replace ' .*'
        $LastCommit = $StartingCommit
        $LastFailed = $false
    }

    process
    {
        $Commit = $Commit -replace ' .*'
        $ShouldRetry = $false
        do
        {
            if ($PSCmdlet.ShouldProcess($(git show -s --oneline $Commit), "Cherry-pick"))
            {
                git cherry-pick $Commit
                $LastFailed = -not $?
            }
            else
            {
                $LastFailed = $false
                return
            }

            $ShouldRetry = -not $LastFailed

            if (-not $?)
            {
                Write-Host "Operation failed. Perform any clean-up, then enter 'exit' to continue:"
                $Host.EnterNestedPrompt()
                Write-Host "We will retry the same commit again. If you wish to skip, answer 'N'"
            }
        }
        while ($ShouldRetry)
    }
}
