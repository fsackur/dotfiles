
$Global:PSDefaultParameterValues['Out-Default:OutVariable'] = '+LastOutput'
$Global:PSDefaultParameterValues['Get-ChildItem:Force'] = $true
$Global:PSDefaultParameterValues['del:Force'] = $true

$Global:HostsFile = if ($IsLinux) {'/etc/hosts'} elseif ($IsMacOS) {''} else {'C:\Windows\System32\drivers\etc\hosts'}

if ($IsLinux)
{
    $XdgDefaults = @{
        XDG_CONFIG_HOME = "$env:HOME/.config"
        XDG_CACHE_HOME = "$env:HOME/.cache"
        XDG_DATA_HOME = "$env:HOME/.local/share"
        XDG_STATE_HOME = "$env:HOME/.local/state"
        XDG_DATA_DIRS = "/usr/local/share:/usr/share"
        XDG_CONFIG_DIRS = "/etc/xdg"
    }
    $XdgDefaults.GetEnumerator() |
        ? {-not (Get-Item env:/$($_.Key) -ErrorAction Ignore)} |
        % {Set-Content env:/$($_.Key) $_.Value}
}

# https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_commonparameters
[string[]]$CommonParameters = (
    'Verbose',
    'Debug',
    'ErrorAction',
    'WarningAction',
    'InformationAction',
    'ErrorVariable',
    'WarningVariable',
    'InformationVariable',
    'OutVariable',
    'OutBuffer',
    'PipelineVariable',
    'WhatIf',
    'Confirm'
)
[Collections.Generic.HashSet[string]]$CommonParameters = [Collections.Generic.HashSet[string]]::new($CommonParameters)


Set-Alias os Out-String
Set-Alias cm chezmoi
Set-Alias tf terraform
Set-Alias k kubectl
Set-Alias p podman
Set-Alias pc podman-compose
Set-Alias clip Set-Clipboard
Set-Alias sort Sort-Object
Set-Alias json ConvertTo-Json
Set-Alias unjson ConvertFrom-Json
if ($IsLinux)
{
    Set-Alias scl systemctl
}

# Save typing out [pscustomobject]
Add-Type 'public class o : System.Management.Automation.PSObject {}' -WarningAction Ignore


# Warns that will only take effect on next start
Enable-ExperimentalFeature PSCommandNotFoundSuggestion, PSSubsystemPluginModel -WarningAction Ignore


# https://devblogs.microsoft.com/powershell/announcing-psreadline-2-1-with-predictive-intellisense/
Set-PSReadLineOption -EditMode Windows
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle InlineView

Set-PSReadlineKeyHandler -Chord Tab -Function TabCompleteNext
Set-PSReadlineKeyHandler -Chord Shift+Tab -Function TabCompletePrevious
Set-PSReadLineKeyHandler -Chord Escape -Function CancelLine
Set-PSReadlineKeyHandler -Chord Ctrl+RightArrow -Function ForwardWord
Set-PSReadlineKeyHandler -Chord Ctrl+LeftArrow -Function BackwardWord
Set-PSReadlineKeyHandler -Chord Ctrl+Shift+LeftArrow -Function SelectBackwardWord
Set-PSReadlineKeyHandler -Chord Ctrl+Shift+RightArrow -Function SelectForwardWord
Set-PSReadlineKeyHandler -Chord Ctrl+Shift+End -Function SelectLine
Set-PSReadlineKeyHandler -Chord Ctrl+Shift+Home -Function SelectBackwardsLine
Set-PSReadLineKeyHandler -Chord Ctrl+a -Function SelectAll
Set-PSReadlineKeyHandler -Chord Ctrl+z -Function Undo
Set-PSReadlineKeyHandler -Chord Ctrl+y -Function Redo
Set-PSReadlineKeyHandler -Chord Shift+Enter -Function InsertLineBelow

if ($IsWindows)
{
    Set-PSReadlineKeyHandler -Chord Ctrl+c -Function CopyOrCancelLine
    Set-PSReadlineKeyHandler -Chord Ctrl+x -Function Cut
    Set-PSReadlineKeyHandler -Chord Ctrl+v -Function Paste
    Set-PSReadlineKeyHandler -Chord Ctrl+Spacebar -Function MenuComplete
}
else
{
    # v2.4 contains the fix for xclip hanging.
    # if (-not (Get-Module -ErrorAction Ignore -FullyQualifiedName @{ModuleName = 'PSReadLine'; ModuleVersion = '2.4'}))
    # {
    #     try
    #     {
    #         Install-Module PSReadLine -MinimumVersion 2.4 -Scope CurrentUser -Force
    #     }
    #     catch
    #     {
    #         Install-Module PSReadLine -AllowPrerelease -Scope CurrentUser -Force
    #     }
    # }

    Set-PSReadlineKeyHandler -Chord Ctrl+c -Function CopyOrCancelLine
    Set-PSReadlineKeyHandler -Chord Ctrl+x -Function Cut
    Set-PSReadlineKeyHandler -Chord Ctrl+v -Function Paste
    Set-PSReadlineKeyHandler -Chord Ctrl+@ -Function MenuComplete  # Unix shells always intercept Ctrl-space - Fedora seems to map it to Ctrl-@
}
<#
    # if (Get-Command copyq -ErrorAction Ignore)
    # {
    #     # $CopyTool = 'copyq'
    #     # $CopyToolArgs = 'add'
    #     $CopyCmd = {copyq add $input}
    #     $PasteArgs = @{ScriptBlock = {[Microsoft.PowerShell.PSConsoleReadLine]::Insert((copyq read 0))}}
    # }

    $CopyTool = $CopyToolArgs = $PasteTool = $PasteToolArgs = $null
    # https://github.com/PowerShell/PSReadLine/issues/1993
    # if (Get-Command copyq -ErrorAction Ignore)
    # {
    #     if (-not (Get-Process copyq -ErrorAction Ignore))
    #     {
    #         copyq &
    #     }

    #     $CopyTool = 'copyq'
    #     $CopyToolArgs = 'add'
    #     $PasteTool = 'copyq'
    #     $PasteToolArgs = 'read 0'
    # }
    if (Get-Command wl-copy -ErrorAction Ignore)
    {
        $CopyTool = 'wl-copy'
        $CopyToolArgs = '-n'
        $PasteTool = 'wl-paste'
        $PasteToolArgs = '-n'
    }
    elseif (Get-Command xsel -ErrorAction Ignore)
    {
        # xclip has weird pipe handling and hangs in pwsh, so use xsel instead
        $CopyTool = 'xsel'
        $CopyToolArgs = '-i --clipboard'
        $PasteTool = 'xsel'
        $PasteToolArgs = '-o'
    }

    if ($CopyTool)
    {
        $CopyCmd = {
            $StartInfo = [Diagnostics.ProcessStartInfo]::new()
            $StartInfo.UseShellExecute = $false
            $StartInfo.RedirectStandardInput = $true
            $StartInfo.RedirectStandardOutput = $true
            $StartInfo.RedirectStandardError = $true
            $StartInfo.FileName = $CopyTool
            $StartInfo.Arguments = $CopyToolArgs
            $Process = [Diagnostics.Process]::Start($StartInfo)
            $Process.StandardInput.Write("$input")
            $Process.StandardInput.Close()
            $Process.StandardOutput.ReadToEnd() | Write-Debug
            [void]$Process.WaitForExit(250)
        }.GetNewClosure()

        # replacement for CopyOrCancelLine and Cut
        $Copy = {
            [string]$Buffer = ''
            [int]$Cursor = 0
            [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$Buffer, [ref]$Cursor)

            [int]$SelStart = 0
            [int]$SelLength = 0
            [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$SelStart, [ref]$SelLength)

            if ($SelStart -eq -1 -and $SelLength -eq -1)
            {
                # Nothing selected; clear the buffer, but add to history in case it was a mistake
                [Microsoft.PowerShell.PSConsoleReadLine]::Delete(0, $Buffer.Length)
                [Microsoft.PowerShell.PSConsoleReadLine]::AddToHistory($Buffer)
                return
            }

            $Buffer.SubString($SelStart, $SelLength) | & $CopyCmd

            if ($Cut)
            {
                [Microsoft.PowerShell.PSConsoleReadLine]::Delete($SelStart, $SelLength)
            }
        }

        $Paste = {
            $Text = if ($PasteToolArgs) {& $PasteTool $PasteToolArgs} else {& $PasteTool}
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert(($Text -join "`n"))
        }

        $Cut = $false
        Set-PSReadLineKeyHandler -Chord Ctrl+c -Description "Copy selection, or cancel line" -ScriptBlock $Copy.GetNewClosure()
        $Cut = $true
        Set-PSReadLineKeyHandler -Chord Ctrl+x -Description "Cut selection" -ScriptBlock $Copy.GetNewClosure()

        Set-PSReadlineKeyHandler -Chord Ctrl+v -Description "Paste text from the system clipboard" -ScriptBlock $Paste.GetNewClosure()
    }
    else
    {
        Write-Host -ForegroundColor Red "wl-clipboard and xsel not found; PSReadline will use internal clipboard."
        Set-PSReadlineKeyHandler -Chord Ctrl+c -Function CopyOrCancelLine
        Set-PSReadlineKeyHandler -Chord Ctrl+x -Function Cut
        Set-PSReadlineKeyHandler -Chord Ctrl+v -Function Paste
    }

    Remove-Variable CopyCmd, CopyTool, CopyToolArgs, Copy, Cut -Scope Global -ErrorAction Ignore
}
#>

# https://gist.github.com/rkeithhill/3103994447fd307b68be
Set-PSReadlineKeyHandler -Chord '(', '[', '{', "'", '"' -Description "Wrap selection in brackets or quotes" -ScriptBlock {
    param ($Key, $Arg)

    $L = $Key.KeyChar.ToString()
    $R = @{
        '(' = ')'
        '[' = ']'
        '{' = '}'
        "'" = "'"
        '"' = '"'
    }[$L]

    $SelStart = $null
    $SelLength = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$SelStart, [ref]$SelLength)

    if ($SelStart -eq -1 -and $SelLength -eq -1)
    {
        # Nothing selected
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($L)
        return
    }

    $Buffer = $null
    $Cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$Buffer, [ref]$Cursor)

    $Replacement = $L + $Buffer.SubString($SelStart, $SelLength) + $R
    [Microsoft.PowerShell.PSConsoleReadLine]::Replace($SelStart, $SelLength, $Replacement)
}

# https://unix.stackexchange.com/questions/196098/copy-paste-in-xfce4-terminal-adds-0-and-1/196574#196574
if ($IsLinux) {printf "\e[?2004l"}

function Get-PSReadlineHistory
{
    gc (Get-PSReadLineOption).HistorySavePath
}

# dotnet tab-completion
if (Get-Command dotnet -ErrorAction Ignore)
{
    Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
        param($commandName, $wordToComplete, $cursorPosition)
        dotnet complete --position $cursorPosition "$wordToComplete" | ForEach-Object {
            [Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'

if ($IsWindows)
{
    Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        $word = $wordToComplete.Replace('"', '""')
        $ast = $commandAst.ToString().Replace('"', '""')
        winget complete --word=$word --commandline $ast --position $cursorPosition | ForEach-Object {
            [Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}

# argc-completions https://github.com/sigoden/argc-completions
if ($false -and $env:GITROOT -and -not $IsWindows)
{
    if (-not (Test-Path $env:GITROOT/argc-completions))
    {
        Push-Location $env:GITROOT -ErrorAction Stop
        try
        {
            git clone ssh://github.com/sigoden/argc-completions --origin upstream --filter=blob:none
            . ./argc-completions/scripts/download-tools.sh
        }
        finally
        {
            Pop-Location
        }
    }

    if (Test-Path "$env:GITROOT/argc-completions/bin/argc")
    {
        $env:ARGC_COMPLETIONS_ROOT = "$env:GITROOT/argc-completions"
        $env:ARGC_COMPLETIONS_PATH = $env:ARGC_COMPLETIONS_ROOT + '/completions'
        $env:PATH = $env:ARGC_COMPLETIONS_ROOT + '/bin' + [IO.Path]::PathSeparator + $env:PATH
        # To add a subset of completions only, change next line e.g. $argc_scripts = @("cargo", "git")
        $argc_scripts = ((Get-ChildItem -File ($env:ARGC_COMPLETIONS_ROOT + '/completions')) | ForEach-Object { $_.Name -replace '\.sh$' })
        argc --argc-completions powershell $argc_scripts | Out-String | Invoke-Expression
    }
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

if (-not $env:SSH_AUTH_SOCK)
{
    [string[]]$SshAgentOutput = @()
    if ($IsLinux -and (Get-Command gnome-keyring-daemon -ErrorAction Ignore))
    {
        $SshAgentOutput = gnome-keyring-daemon --start
    }
    else
    {
        $SshAgentOutput = $(ssh-agent) -replace ';.*' | Select-Object -SkipLast 1
    }
    $env:SSH_AUTH_SOCK = $SshAgentOutput -match 'SSH_AUTH_SOCK' -replace '.*='
}
