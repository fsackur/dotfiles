# function clean {gci *.json, *.txt -Exclude requirements*.txt | del; a | Out-Null; git status -s}
# function cont {git rebase --continue}
# function msg {gci ./.git -Filter COMMIT_EDITMSG, MERGE_EDITMSG | % {$_.Name; gc $_ | select -First 8}}
# function msg {gci .git/COMMIT_EDITMSG, .git/MERGE_EDITMSG -ea Ignore | % {$_.Name; gc $_ | select -First 8}}
# function tinue {git rebase --continue}
# function no {gci *.json, *.txt -Exclude requirements*.txt | del; a | Out-Null; git status -s}
# function msg {gci .git/COMMIT_EDITMSG, .git/MERGE_MSG -ea Ignore | % {$_.Name; gc $_ | select -First 8}}


# $rtd = gc /home/freddie/gitroot/upstream/opnsense/core/.git/rebase-merge/git-rebase-todo
# $rtd | replace "^pick", "edit" > /home/freddie/gitroot/upstream/opnsense/core/.git/rebase-merge/git-rebase-todo


$GitDir = git rev-parse --show-toplevel
$MergeMsgPath = "$GitDir/.git/MERGE_MSG"

$DefaultAction = {
    pushd $GitDir -ErrorAction Stop
    try
    {
        gci *.json, *.txt -Exclude requirements*.txt | del
    }
    finally
    {
        popd
    }
}

function tinue {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
    # bool ShouldContinue(string query, string caption)
    # bool ShouldContinue(string query, string caption, [ref] bool yesToAll, [ref] bool noToAll)
    # bool ShouldContinue(string query, string caption, bool hasSecurityImpact, [ref] bool yesToAll, [ref] bool noToAll)
    # bool ShouldProcess(string target)
    # bool ShouldProcess(string target, string action)
    # bool ShouldProcess(string verboseDescription, string verboseWarning, string caption)
    # bool ShouldProcess(string verboseDescription, string verboseWarning, string caption, [ref] System.Management.Automation.ShouldProcessReason shouldProcessReason)
    param
    (
        [scriptblock]$Action = $DefaultAction
    )

    # git config --global alias.lg "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative"

    # $StarshipConfig = starship print-config character.format -d | Parse-IniConf -Unquote
    # $PromptFormat = $StarshipConfig.character.format
    try
    {
        $Changes = (git -c color.ui=always status -s) -replace '^\s+' -replace '\s+', " "

        $IsConflict = Test-Path $MergeMsgPath
        if ($IsConflict) {
            if ($PSCmdlet.ShouldProcess($changes, "merge conflicts")) {
                $ChangedFiles = $Changes -replace '^\S+\s+' | Resolve-Path -ErrorAction Ignore
                if ($ChangedFiles) {
                    $Markers = $ChangedFiles | gci | sls -Pattern "======="
                    if ($Markers) {
                        if (-not $PSCmdlet.ShouldProcess($changes, "merge conflicts")) {
                            return
                        }
                    }
                }

                git add $GitDir
                git -c core.editor=true rebase --continue
                return & $MyInvocation.MyCommand
            } else {
                return
            }
        }

        & $Action

        $Changes = (git -c color.ui=always status -s) -replace '^\s+' -replace '\s+', " "
        if ($Changes) {
            # $LastMessage = git show -s --format=%s HEAD
            $LastMessage = gc "$GitDir/.git/rebase-merge/message"
            if ($PSCmdlet.ShouldProcess($changes, "amend commit '$LastMessage'")) {
                git add $GitDir
                git commit --amend --no-edit
                return & $MyInvocation.MyCommand
            } else {
                return
            }
        }

        git rebase --continue
    }
    finally
    {

    }
}

<#
[Microsoft.PowerShell.PSConsoleReadLine].GetMethods().Name | clip
Abort
AcceptAndGetNext
AcceptLine

AddLine
AddToHistory

BeginningOfLine
CaptureScreen
ClearScreen
Complete

DigitArgument
Ding

EndOfHistory
EndOfLine

GetDefaultAddToHistoryOption
GetDisplayGrouping
GetHistoryItems

GotoFirstNonBlankOfLine
HistorySearchBackward
HistorySearchForward
Insert
Insert

InvertCase

InvokePrompt

PossibleCompletions

ReadLine
ReadLine

RevertLine

ScrollDisplayDown
ScrollDisplayDownLine
ScrollDisplayToCursor
ScrollDisplayTop
ScrollDisplayUp
ScrollDisplayUpLine

SetCursorPosition

ShowCommandHelp

ShowKeyBindings
ShowParameterHelp
SwapCharacters
SwitchPredictionView
TabCompleteNext
TabCompletePrevious
TryGetArgAsInt
ValidateAndAcceptLine
#>
