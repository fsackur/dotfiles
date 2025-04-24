
function Get-GitDir {
    param (
        [Parameter(ValueFromPipelineByPropertyName, ValueFromPipeline, Position = 0)]
        [Alias("Path")]
        $Dir = $PWD
    )
    git -C $GitDir rev-parse --show-toplevel
}

function Test-IsRebasing {
    param ($GitDir = (Get-GitDir))
    (Test-Path "$GitDir/.git/rebase-merge") -or
    (Test-Path "$GitDir/.git/rebase-apply")
}

$RebaseActions = "p", "pick", "r", "reword", "e", "edit", "s", "squash", "f", "fixup", "x", "exec", "b", "break", "d", "drop", "l", "label", "t", "reset", "m", "merge", "u", "update-ref"
$ActionPattern = "(?<Action>$($RebaseActions -join '|')(\s+-[cC])?)"
$RefPattern = "((?<Ref>[a-fA-F0-9]{7})[a-fA-F0-9]*|(?<Ref>\S+))"
$RebasePattern = "^\s*$ActionPattern\s+$RefPattern(\s+(?<Message>.*))?\s*$"

class RebaseCommit
{
    [string]$Action
    [string]$Ref
    [string]$Message

    static [RebaseCommit] Parse([string]$Line) {
        if ($Line -notmatch $Script:RebasePattern) {
            throw "Could not parse '$Line"
        }
        0..6 | % {$Matches.Remove($_)}
        return [RebaseCommit]$Matches
    }

    [string] ToString() {
        return $this.Action, $this.Ref, $this.Message -join " "
    }
}

class RebaseStatus
{
    [int]$Current
    [int]$Total
    [RebaseCommit[]]$Done
    [RebaseCommit[]]$ToDo

    [string] ToString() {
        return "($($this.Current)/$($this.Total)) $($this.ToDo[0])"
    }
}

function Get-RebaseStatus {
    param ($GitDir = (Get-GitDir))
    if (-not (Test-Path "$GitDir/.git/rebase-merge/")) {
        return
        # TODO:
        #     "$GitDir/.git/rebase-apply/next", "$GitDir/.git/rebase-apply/last"
    }
    [RebaseStatus]@{
        Current = Get-Content "$GitDir/.git/rebase-merge/msgnum"
        Total = Get-Content "$GitDir/.git/rebase-merge/end"
        Done = Get-Content "$GitDir/.git/rebase-merge/done" | % {[RebaseCommit]::Parse($_)}
        ToDo = Get-Content "$GitDir/.git/rebase-merge/git-rebase-todo" | % {[RebaseCommit]::Parse($_)}
    }
}

function Step-Rebase {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
    param
    (
        [scriptblock]$Action,

        [string]$GitDir = (Get-GitDir)
    )

    if (-not (Test-IsRebasing)) {return}
    $null = git -C $GitDir -c color.ui=always -c core.editor=true rebase --continue *>&1
    if (-not (Test-IsRebasing)) {return}

    $Status = Get-RebaseStatus
    $IsConflict = Test-Path "$GitDir/.git/MERGE_MSG"
    if (-not $IsConflict) {
        $Status -as [string]

        if ($Status.Done[-1].Action -in "e", "edit") {
            "You can amend the commit now. Type 'exit' when done."
            $Host.EnterNestedPrompt()
        }

    } else {
        "Conflict in $($Status.Ref) $($Status.Message)"
        $Changes = (git -C $GitDir -c color.ui=always status -s) -replace '^\s+' -replace '\s+', " "
        if ($PSCmdlet.ShouldProcess($Changes, "merge conflicts")) {
            $ChangedFiles = $Changes -replace '^\S+\s+' | Resolve-Path -ErrorAction Ignore
            if ($ChangedFiles) {
                $Markers = $ChangedFiles | Get-ChildItem | Select-String "<<<<<<"
                if ($Markers) {
                    if (-not $PSCmdlet.ShouldProcess($Markers, "merge in spite of conflicts")) {
                        return
                    }
                }
            }

            git -C $GitDir add $GitDir
            return & $MyInvocation.MyCommand @PSBoundParameters
        } else {
            return
        }
    }

    if ($Action) {
        & $Action
    }

    $Changes = (git -C $GitDir -c color.ui=always status -s) -replace '^\s+' -replace '\s+', " "
    if ($Changes) {
        $Changes
        $LastMessage = Get-Content "$GitDir/.git/rebase-merge/message"
        if ($PSCmdlet.ShouldProcess($changes, "amend commit '$LastMessage'")) {
            git -C $GitDir add $GitDir
            $null = git -C $GitDir commit --amend --no-edit *>&1
            return & $MyInvocation.MyCommand
        } else {
            return
        }
    }

    return & $MyInvocation.MyCommand @PSBoundParameters
}

function rebase {
    [CmdletBinding(DefaultParameterSetName = "Invoke")]
    param
    (
        [Parameter(ParameterSetName = "Mode", Mandatory, Position = 0)]
        [ValidateSet("continue", "skip", "abort", "quit", "edit-todo", "show-current-patch")]
        [string]$Command,

        [Parameter(ParameterSetName = "Invoke", Mandatory, Position = 0)]
        [ArgumentCompleter({
            param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

            $DirArgs = @{GitDir = if ($fakeBoundParameters.GitDir) {$fakeBoundParameters.GitDir} else {Get-GitDir}}

            if (Test-IsRebasing @DirArgs) {
                $word = $wordToComplete -replace '^-+'
                $Commands = "continue", "skip", "abort", "quit", "edit-todo", "show-current-patch"
                ($Commands -like "$word*"), ($Commands -like "*$word*") | Write-Output | Select-Object -Unique

            } elseif ($wordToComplete -match '^\d+$') {
                Write-Host "foo"
                @("HEAD$wordToComplete")

            } else {
                $Refs = (git -C $GitDir show-ref)[0..15] -replace '.* refs/\w+/'
                ($Refs -like "$word*"), ($Refs -like "*$word*") | Write-Output | Select-Object -Unique
            }
        })]
        [string]$Upstream,

        [Parameter(ParameterSetName = "Invoke")]
        [string]$Branch,

        [Parameter(ParameterSetName = "Invoke")]
        [string]$Onto,

        [scriptblock]$Exec,

        [Parameter(ParameterSetName = "Invoke")]
        [Alias("keep-empty")]
        [switch]$KeepEmpty,

        [Parameter(ParameterSetName = "Invoke")]
        [switch]$Interactive,

        [Parameter(ParameterSetName = "Invoke")]
        [switch]$Autosquash,

        [Parameter(ParameterSetName = "Invoke")]
        [switch]$Autostash,

        [Alias("Path", "RepoPath")]
        [string]$GitDir = (Get-GitDir)
    )

    [string[]]$RebaseArgs = @()

    if ($PSCmdlet.ParameterSetName -eq "Mode") {
        if (-not (Test-IsRebasing)) {
            throw "Not rebasing"
        }

        $RebaseArgs = @("--$Command")

    } else {
        if (Test-IsRebasing) {
            $Command = $Upstream -replace "^-+"
            return & $MyInvocation.MyCommand -Command $Command
        }

        [void]$PSBoundParameters.Remove("Upstream")
        [void]$PSBoundParameters.Remove("Branch")
        [void]$PSBoundParameters.Remove("GitDir")

        $StepArgs = @{GitDir = $GitDir}
        if ($PSBoundParameters.Remove("Exec")) {$StepArgs["Action"] = $Exec}

        $RebaseArgs = $PSBoundParameters.GetEnumerator() | % {
            $Param = $MyInvocation.MyCommand.Parameters[$_.Key]
            if ($Param.SwitchParameter -and -not $_.Value) {return}

            $GitName = $Param.Aliases, $Param.Name | Write-Output | Select-Object -First 1
            "--$($GitName.ToLower())"
            if ($Param.SwitchParameter) {return}

            $_.Value

        } | Write-Output

        $RebaseArgs += $Upstream
        if ($Branch) {$RebaseArgs += $Branch}
    }

    # -c sequence.editor="pwsh -nop -c edit-rebase"
    if ($Interactive) {
        $RebaseOutput = git -C $GitDir -c color.ui=always rebase @RebaseArgs *>&1
        Step-Rebase @StepArgs
    } else {
        git -C $GitDir rebase @RebaseArgs
    }

}
