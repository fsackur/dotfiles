
Set-Alias clip Set-Clipboard


[console]::OutputEncoding = [Text.Encoding]::UTF8

Set-PSReadLineOption -PredictionSource History
Set-PSReadlineKeyHandler -Chord Tab -Function TabCompleteNext
Set-PSReadlineKeyHandler -Chord Shift+Tab -Function TabCompletePrevious
# Set-PSReadlineKeyHandler -Chord Ctrl+Spacebar -Function MenuComplete      # https://github.com/microsoft/terminal/issues/2865
Set-PSReadlineKeyHandler -Chord Ctrl+p -Function MenuComplete
Set-PSReadLineKeyHandler -Chord Escape -Function CancelLine
Set-PSReadlineKeyHandler -Chord Ctrl+RightArrow -Function ForwardWord
Set-PSReadlineKeyHandler -Chord Ctrl+LeftArrow -Function BackwardWord
Set-PSReadlineKeyHandler -Chord Ctrl+Shift+LeftArrow -Function SelectBackwardWord
Set-PSReadlineKeyHandler -Chord Ctrl+Shift+RightArrow -Function SelectForwardWord
Set-PSReadlineKeyHandler -Chord Ctrl+Shift+End -Function SelectLine
Set-PSReadlineKeyHandler -Chord Ctrl+Shift+Home -Function SelectBackwardsLine
Set-PSReadLineKeyHandler -Chord Ctrl-a -Function SelectAll
Set-PSReadlineKeyHandler -Chord Ctrl+c -Function CopyOrCancelLine         # https://github.com/PowerShell/PSReadLine/issues/1993
Set-PSReadlineKeyHandler -Chord Ctrl+x -Function Cut                      # https://github.com/PowerShell/PSReadLine/issues/1993
Set-PSReadlineKeyHandler -Chord Ctrl+z -Function Undo
Set-PSReadlineKeyHandler -Chord Ctrl+y -Function Redo

function Get-PSReadlineHistory
{
    gc (Get-PSReadLineOption).HistorySavePath
}

if ($Global:IS_RASPBERRY_PI)   # too slow
{}
elseif ($PSVersionTable.PSVersion.Major -ge 7)
{
    ipmo oh-my-posh -Global
    if ($IS_LINUX -and -not $env:POSH_THEMES_PATH)
    {
        $env:POSH_THEMES_PATH = $env:POSH_THEME | Split-Path
    }
    $AmroGit = $env:POSH_THEMES_PATH | Join-Path -ChildPath amro-git.omp.json
    if (-not (Test-Path $AmroGit))
    {
        $LocalPath = $PSScriptRoot | Split-Path | Join-Path -ChildPath .oh-my-posh | Join-Path -ChildPath themes | Join-Path -ChildPath amro-git.omp.json
        New-Item -ItemType SymbolicLink $AmroGit -Value $LocalPath
    }
    Set-PoshPrompt amro-git
}
else
{
    Set-PoshPrompt pure
}

Import-Module posh-git

$PSDefaultParameterValues += @{
    'Out-Default:OutVariable' = '+LastOutput'
}


$HistoryHandler = {
    <#
        USE WITH CAUTION

        By default, PSReadline will not add an invocation to the history if it contains any of the
        following text:

        - password
        - asplaintext
        - token
        - apikey
        - secret

        The history file is unencrypted, so obviously secret content should not be added.

        This handler does further parsing on invocations containing those keywords. It examines
        strings in the invocation and assumes that strings that themselves contain those keywords
        are not secret.

        Consider this invocation:

            Get-Secret -Name GithubToken

        This handler would add this invocation where the default handler would not. The handler
        finds these strings: 'Get-Secret' (which is resolved dynamically) and 'GithubToken'.

        However, the handler would not add the folowing invocation:

            Set-Secret -Name GithubToken -Password deadbeefdeadbeefdeadbeefdeadbeef

        This invocation will only be added to the in-memory history.

        The danger is in something like this:

            Set-Secret -Name GithubToken -Password "token: deadbeefdeadbeefdeadbeefdeadbeef"

        In this case, the handler will add the invocation to history.

        YOU MUST MANUALLY CLEAR THE HISTORY if you supply a secret at the commond line where the
        secret itself contains any of the keywords listed:

            Clear-History -Count 5      # clear the last 5 items from the history file
    #>
    param ([string]$Line)

    $Pattern = "password|asplaintext|token|apikey|secret"
    if ($Line -notmatch $Pattern)
    {
        return [Microsoft.PowerShell.AddToHistoryOption]::MemoryAndFile
    }

    $Ast        = [Management.Automation.Language.Parser]::ParseInput($Line, [ref]$null, [ref]$null)
    $StringAsts = $Ast.FindAll({param($Ast) $Ast -is [Management.Automation.Language.StringConstantExpressionAst]}, $true)
    $Strings    = @($StringAsts.Value)

    # Assumption: a string containing, e.g., 'secret' isn't an _actual_ secret
    if ($Strings -notmatch $Pattern)
    {
        return [Microsoft.PowerShell.AddToHistoryOption]::MemoryOnly
    }
    else
    {
        return [Microsoft.PowerShell.AddToHistoryOption]::MemoryAndFile
    }
}
Set-PSReadlineOption -AddToHistoryHandler $HistoryHandler
