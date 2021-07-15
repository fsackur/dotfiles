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
    git commit -m $Message
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

        .PARAMETER MergesOnly
        Specifies to only show merges, not individual commits.

        .PARAMETER Reflog
        Specifies to retreive the reflog instead of the commit history. The reflog is git plumbing
        that can help undo operations.

        .PARAMETER Undoable
        Specifies to retrieve a view of the reflog where atomic operations in an action such as a
        rebase are combined into a single object, representing an action such as a rebase.

        .PARAMETER Count
        Specify how many commits to retrieve.

        .PARAMETER FromRef
        Providing a starting reference (branch, tag or commit).

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

        [Parameter(ParameterSetName = 'MergesOnly', Mandatory)]
        [switch]$MergesOnly,

        [Parameter(ParameterSetName = 'Reflog', Mandatory)]
        [switch]$Reflog,

        [Parameter(ParameterSetName = 'ReflogAction', Mandatory)]
        [switch]$Undoable,

        [Parameter(ParameterSetName = 'Reflog', Position = 0)]
        [Parameter(ParameterSetName = 'ReflogAction', Position = 0)]
        [Parameter(ParameterSetName = 'MergesOnly', Position = 0)]
        [Parameter(ParameterSetName = 'Default', Position = 0)]
        [ValidateRange(1, 5000)]
        [Alias('Commits')]  # Backward-compatibility
        [int]$Count,

        [Parameter(ParameterSetName = 'Reflog')]
        [Parameter(ParameterSetName = 'MergesOnly')]
        [Parameter(ParameterSetName = 'Default')]
        [string]$FromRef,

        [Parameter()]
        [string]$Remote,

        [Parameter()]
        [string]$Branch,

        [Parameter(ParameterSetName = 'Default')]
        [Parameter()]
        [int]$Weeks,

        [Parameter()]
        [switch]$SortDescending
    )


    $SinceLastPRMerge = $PSCmdlet.ParameterSetName -eq 'SinceLastPRMerge'

    if (-not $PSBoundParameters.ContainsKey('InformationAction'))
    {
        # Caller was a function in this module
        if ((Get-PSCallStack)[1].InvocationInfo.MyCommand.Module -eq $MyInvocation.MyCommand.Module)
        {
            $InformationPreference = 'SilentlyContinue'
        }
        else
        {
            $InformationPreference = 'Continue'
        }
    }


    $ToRef  = "HEAD"
    $Header = ""

    # https://git-scm.com/docs/git-log#_pretty_formats
    $Format = if ($Reflog)
    {
        [ordered]@{
            ReflogId = '%gd'
            Action   = '%gs'
            Id       = '%h'
            Summary  = '%s'
        }
    }
    elseif ($Undoable)
    {
        [ordered]@{
            ReflogId   = '%gd'
            Action     = '%gs'
            PreviousId = ''
            Id         = '%h'
            Summary    = '%s'
        }
    }
    else
    {
        [ordered]@{
            Id        = '%h'
            Author    = '%an'
            UpdatedAt = '%ar'
            Summary   = '%s'
        }
    }
    $OutputProperties = @($Format.Keys)


    [string[]]$LogArgs = if ($Reflog -or $Undoable) {'reflog'} else {'log'}


    $OFS          = [char]31    # random non-printing char that we don't expect to find in git output
    $FormatString = $Format.Values -join $OFS
    $LogArgs += "--pretty=format:$FormatString"


    if (-not $Count -and -not $FromRef)
    {
        $Count = switch ($PSCmdlet.ParameterSetName)
        {
            'MergesOnly'        {6}
            'SinceLastPRMerge'  {500}
            'Reflog'            {60}
            'ReflogAction'      {500}
            default             {12}
        }
    }

    if ($Count -and -not $Undoable) {$LogArgs += "-n $Count"}

    if ($MergesOnly) {$LogArgs += "--merges"}

    if ($Weeks) {$LogArgs += "--since=$Weeks.weeks"}

    if ($Remote -or $Branch)
    {
        if (-not $Branch) {$Branch = git branch --show-current}

        $ToRef = $Remote, $Branch -join '/' -replace '^/'
        $Header = "Branch: $ToRef"
    }

    if ($SinceLastPRMerge)
    {
        $LastMerge = Get-GitLog -MergesOnly -Count 1
        $FromRef = $LastMerge.Id
    }

    if ($FromRef)
    {
        $RefRange = "$FromRef..$ToRef"
        $LogArgs += $RefRange

        if ($PSBoundParameters.ContainsKey('FromRef'))
        {
            $Header = "Range: $RefRange"
        }
    }
    else
    {
        $LogArgs += $ToRef
    }


    # Do the thing
    $CommitLines = & git $LogArgs


    if ($SinceLastPRMerge)
    {
        $CommitLines = $CommitLines.Where({$_ -match 'whamapi-cicd-svc|;Merge pull request'}, 'Until')
    }


    $Output = $CommitLines | ConvertFrom-Csv -Delimiter $OFS -Header $OutputProperties
    $Output | ForEach-Object {$_.PSTypeNames.Insert(0, 'GitCommit')}


    if ($Reflog)
    {
        $Output | ForEach-Object {
            $Action = $_.Action
            $Action = $Action -replace ": $([regex]::Escape($_.Summary))"
            $Action = $Action -replace ': returning to.*'
            $Action = $Action -replace ': checkout ', ' -> '
            $Action = $Action -replace '^checkout: moving from (\S+) to (\S+)$', 'checkout ($1 -> $2)'
            $_.Action = $Action
        }
        $Output | Add-Member -Force ScriptMethod ToString {'{0} {1} {2} {3}' -f $this.PSObject.Properties.Value}
    }
    elseif ($Undoable)
    {
        $ActionOutput = [Collections.Generic.List[psobject]]::new()

        $Transaction  = $null
        $Previous     = @{}
        foreach ($Commit in $Output)
        {
            $Action = $Commit.Action

            if ($Transaction)
            {
                if ($Action -match '^rebase \(start\)')
                {
                    $Transaction = $null
                    # $Commit is now the commit we moved back to when we did the rebase, so skip this one too
                }
                continue
            }

            if ($Action -match '^rebase .*\(finish\)')
            {
                $Transaction = 'rebase'
            }


            $Previous.PreviousId = $Commit.Id
            # Filter no-op refs (e.g. a reset to the same commit)
            if ($Previous.Id -eq $Previous.PreviousId)
            {
                $ActionOutput.RemoveAt(($ActionOutput.Count -1))
            }

            $Action = $Action -replace '^commit .*\(amend\).*', 'amend'
            $Action = $Action -replace '^checkout: moving from .* (\S+)$', 'checkout $1'
            $Action = $Action -replace ':? .*'
            $Commit.Action = $Action

            $ActionOutput.Add($Commit)
            $Previous = $Commit     # Still needs PreviousId
        }

        $Output = $ActionOutput | Select-Object -First $Count
        $Output | Add-Member -Force ScriptMethod ToString {'{0} {1} {2}..{3} {4}' -f $this.PSObject.Properties.Value}
    }
    else
    {
        $Output | Add-Member -Force ScriptMethod ToString {"$($this.Id): $($this.Summary)"}
    }


    if ($SortDescending)
    {
        [array]::Reverse($Output)
    }


    Write-Information "`n    $Header Count: $($Output.Count)`n"

    $Output
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

function Show-GithubCode
{
    <#
        .SYNOPSIS
        Opens the browser to a shareable link to a file in Github.

        .PARAMETER Line
        Provide one line number to link to a line, or two numbers to link to a range of lines.

        .PARAMETER Permalink
        By default, this command will link to a file in a branch, by branch name. If that branch
        changes, the link may no longer be correct. Using -Permalink links to the branch head by
        commit ID instead of branch name. This may stop showing the latest code, but will always
        show the same code.
    #>
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ArgumentCompleter({
            param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            @(git remote) -like "*$wordToComplete*"
        })]
        [string]$Remote,

        [Parameter()]
        [ArgumentCompleter({
            param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            @(git branch) -replace '^..' -like "*$wordToComplete*"
        })]
        [string]$Branch,

        [Parameter(Mandatory, Position = 0)]
        [ArgumentCompleter({
            param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

            git rev-parse --git-dir | Resolve-Path | Split-Path | Push-Location

            # We probably don't want to link to docs
            $Files = Get-ChildItem -Exclude '.git', 'docs' |
                Get-ChildItem -File -Recurse |
                Select-Object -ExpandProperty FullName |
                Sort-Object |
                Resolve-Path -Relative

            Pop-Location

            $Files -replace '^\.\\' -replace '^\./' -like "*$wordToComplete*"
        })]
        [string]$File,

        [Parameter(Position = 0)]
        [ValidateCount(1, 2)]
        [ValidateRange(1, 65535)]
        [int[]]$Line,

        [Parameter()]
        [switch]$Permalink
    )

    $Output = git rev-parse --git-dir 2>&1
    if (-not $?)
    {
        # fatal: not a git repository (or any of the parent directories): .git
        throw $Output
    }

    if ($Branch)
    {
        $BranchText = @(git branch -vv) -match "^..$Branch " -replace "^.."
    }
    else
    {
        $BranchText = @(git branch -vv) -match '^\*' -replace '^\* '
        $Branch     = $BranchText -replace ' .*'
    }

    if ($Remote)
    {
        $TrackingBranch = $Remote, $Branch -join '/'
    }
    else
    {
        $TrackingBranch = $BranchText -replace '.*?\[' -replace '[:\]].*'
        $Remote         = $TrackingBranch -replace '/.*'
    }

    # Link to exact commit, so won't change if branch is updated
    if ($Permalink)
    {
        $Ref = (git rev-parse $TrackingBranch).Substring(0, 7)
    }
    else
    {
        $Ref = $Branch
    }

    # Drop leading dot; convert \ to /
    if ([System.IO.Path]::DirectorySeparatorChar -eq '\')
    {
        $File = $File -replace '^\.\\' -replace '\\', '/'
    }
    else
    {
        $File = $File -replace '^\./'
    }

    $RemoteUri = @(git remote -vv) -match "^$Remote" -replace "^\w+\s+" -replace ' .*' | Select-Object -First 1
    $Uri       = $RemoteUri, "blob", $Ref, $File -join '/'

    if ($Line)
    {
        $LineQuery = $Line -replace '^', 'L' -join '-'
        $Uri       = $Uri, $LineQuery -join '#'
    }

    Start-Process $Uri
}
