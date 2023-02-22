using namespace System.Collections.Generic


function Git-Branch
{
    [CmdletBinding(DefaultParameterSetName = 'Track')]
    param
    (
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [string]$Head = 'HEAD',

        [Parameter(ParameterSetName = 'Track')]
        [string]$Remote = 'origin',

        [Parameter(ParameterSetName = 'NoTrack')]
        [switch]$NoTrack,

        [switch]$NoSwitch
    )

    $Output = git branch $Name $Head *>&1 | Out-String | foreach TrimEnd
    if ($?) {Write-Host $Output} else {throw $Output}

    if ($PSCmdlet.ParameterSetName -eq 'Track')
    {
        $Output = git push $Remote $Name`:$Name *>&1 | Out-String | foreach TrimEnd
        if ($?) {Write-Host $Output} else {throw $Output}

        $Output = git branch $Name --set-upstream-to $Remote/$Name *>&1 | Out-String | foreach TrimEnd
        if ($?) {Write-Host $Output} else {throw $Output}
    }

    if (-not $NoSwitch)
    {
        $Output = git switch $Name *>&1 | Out-String | foreach TrimEnd
        if (-not $?) {throw $Output}
    }
}
Set-Alias b Git-Branch



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


if (ipmo Victor -Global -PassThru -ErrorAction SilentlyContinue)
{
    return
}



function Git-Add
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string[]]$File = '*',

        [switch]$Patch
    )
    $ArgumentList = $File
    if ($Patch) {$ArgumentList += '--patch'}
    & git add $ArgumentList; git status -v; git status
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
    [CmdletBinding(DefaultParameterSetName = 'SinceLastMerge')]
    param
    (
        [Parameter(ParameterSetName = 'Path')]
        [string]$Path,

        [Parameter(ParameterSetName = 'Path')]
        [switch]$Follow,

        [Parameter(ParameterSetName = 'SinceLastMerge')]
        [switch]$SinceLastMerge,

        [Parameter(ParameterSetName = 'ByCount', Position = 0)]
        [ValidateRange(1, 5000)]
        [int]$Count = 30,

        [Parameter(ParameterSetName = 'FromRef')]
        [Parameter(ParameterSetName = 'Path')]
        [string]$From,

        [Parameter()]
        [switch]$SortDescending,

        [Parameter()]
        [ValidateSet('Relative', 'DateTime')]
        [string]$DateFormat = 'Relative'
    )

    $AsDatetime = $DateFormat -eq 'DateTime'

    if ($PSCmdlet.ParameterSetName -eq 'SinceLastMerge')
    {
        $From = git log --merges -n 1 --format=%h

        if (-not $From)
        {
            $From = git rev-list --max-parents=0 HEAD --abbrev-commit | Select-Object -First 1
        }
    }


    $LogArgs = [List[string]]::new()
    $LogArgs.Add("log")

    if ($From)
    {
        $LogArgs.Add("$From..HEAD")
    }
    else
    {
        $LogArgs.Add("-n $Count")
    }

    if ($SortDescending)
    {
        $LogArgs.Add("--reverse")
    }

    # https://git-scm.com/docs/git-log#_pretty_formats
    $Format = [ordered]@{
        Id         = '%h'
        Author     = '%an'
        AuthorDate = if ($AsDatetime) {'%ai'} else {'%ar'}
        Summary    = '%s'
    }
    $OutputProperties = @($Format.Keys)

    $Delim        = [char]0x2007    # unusual space char that we don't expect to find in git output
    $FormatString = $Format.Values -join $Delim
    $LogArgs.Add("--pretty=format:$FormatString")

    if ($Follow)
    {
        $LogArgs.Add("--follow")
    }

    if ($Path)
    {
        $LogArgs.Add("--name-only")
        $LogArgs.Add("-p")
        $LogArgs.Add($Path)
    }


    # Do the thing
    $CommitLines = & git $LogArgs

    $Commits = $CommitLines | ConvertFrom-Csv -Delimiter $Delim -Header $OutputProperties

    if ($Path)
    {
        # Hack until I can get rid of diff output entirely
        $Commits = $Commits | Where-Object -Property Author
    }

    if ($AsDatetime)
    {
        $Commits | ForEach-Object {$_.AuthorDate = [datetime]$_.AuthorDate}
    }

    $Commits
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
        [string]$Remote = 'origin',

        [Parameter()]
        [ArgumentCompleter({
            param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

            $Branches = Get-GitBranch
            $Completions = $Branches.Name, $Branches.Tracking | ForEach-Object {$_}
            $Completions -like "*$wordToComplete*"
        })]
        [string]$Branch,

        [Parameter(Position = 0)]
        [string]$Path = '.',

        [Parameter(Position = 1)]
        [ValidateRange(1, 65535)]
        [int[]]$Line,

        [Parameter()]
        [switch]$Permalink,

        [switch]$ShowWindow
    )

    $ErrorActionPreference = 'Stop'


    $BranchName = $Branch
    Remove-Variable Branch -ErrorAction SilentlyContinue

    if ($Line)
    {
        $Line = $Line | Sort-Object -Unique
        $Line = @($Line)[0,-1] | Sort-Object -Unique
    }


    $RepoRoot = git rev-parse --show-cdup 2>&1  # --git-dir follows symlinks; --show-cdup navs to repo root like, e.g., '../'
    if (-not $?) {throw $RepoRoot}    # fatal: not a git repository (or any of the parent directories): .git
    $RepoRoot = if ($RepoRoot) {$RepoRoot | Resolve-Path} else {$PWD}
    Write-Verbose "Git repo root: '$RepoRoot'"


    $Item = Get-Item $Path
    if ($Item.Count -gt 1)
    {
        throw [ArgumentException]::new("Path '$Path' matched more than one item.", 'Path')
    }
    $IsContainer = $Item.PSIsContainer
    $Path = $Item.FullName
    Write-Verbose "Item to show: '$Path'"

    if ($Path -eq $RepoRoot)
    {
        $Path = ''
    }
    else
    {
        Push-Location $RepoRoot
        try
        {
            $Path = Resolve-Path $Path -Relative
            Write-Verbose "Resolved path in repo: '$Path'"
        }
        finally
        {
            Pop-Location
        }

        $Path = $Path -replace '^\.\\' -replace '^\./'
        if ([System.IO.Path]::DirectorySeparatorChar -eq '\')
        {
            $Path = $Path -replace '\\', '/'
        }
    }


    $Branches = Get-GitBranch

    if ($BranchName -match '/')
    {
        $Branch = $Branches | Where-Object Tracking -eq $BranchName | Select-Object -First 1
    }
    elseif ($BranchName)
    {
        $Branch = $Branches | Where-Object Name -eq $BranchName | Select-Object -First 1
    }
    else
    {
        $Branch = $Branches | Where-Object Current -eq $true
    }

    if (-not $Branch)
    {
        throw "No matching branch found."
    }


    if ($PSBoundParameters.ContainsKey('Remote') -or -not $Branch.Tracking)
    {
        $Tracking = $Remote, $Branch.Name -join '/'
    }
    else
    {
        $Tracking = $Branch.Tracking
        $Remote = $Tracking -replace '/.*'
    }

    # Link to exact commit, so won't change if branch is updated
    if ($Permalink)
    {
        $Ref = (git rev-parse $Tracking).Substring(0, 7)
        if (-not $?) {throw $Ref}
    }
    else
    {
        $Ref = $Branch.Name
    }


    $RemoteUri = @(git remote -vv) -match "^$Remote" -replace "^\w+\s+" -replace ' .*' -replace '\.git$' | Select-Object -First 1
    if ($RemoteUri -notmatch '^https?://')
    {
        throw [NotImplementedException]::new("Only http schemes are supported: $RemoteUri")
    }
    $Uri = $RemoteUri, $(if ($IsContainer) {"tree"} else {"blob"}), $Ref, $Path -join '/'

    if ($Line)
    {
        $L   = $Line -replace '^', 'L' -join '-'
        $Uri = $Uri, $L -join '#'
    }

    $Uri

    if ($ShowWindow) {Start-Process $Uri}
}

function Get-GitBranch
{
    $OutputProperties = 'Current', 'Name', 'Tracking', 'Sha'

    $BranchPattern = (
        '^(?<Current>.)',
        '(?<Name>\S+)',
        '(?<Sha>\S+)',
        '(?:\[(?<Tracking>[^\]]+)\])?'
    ) -join '\s+'

    $BranchOutput = @(git branch -vv)
    $BranchOutput | ForEach-Object {
        if ($_ -match $BranchPattern)
        {
            $Matches.Remove(0)
            $Output = [pscustomobject]$Matches
            $Output.Current = $Output.Current -eq '*'
            $Output
        }
    } | Select-Object $OutputProperties
}
