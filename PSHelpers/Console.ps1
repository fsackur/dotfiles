
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
    'ProgressAction',
    'OutVariable',
    'OutBuffer',
    'PipelineVariable',
    'WhatIf',
    'Confirm'
)
[Collections.Generic.HashSet[string]]$CommonParameters = [Collections.Generic.HashSet[string]]::new($CommonParameters)

$ArgumentCompleterSnippet = @'
{
    param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    $Names = @()
    (@($Names) -like "$wordToComplete*"), (@($Names) -like "*$wordToComplete*") | Write-Output | Select-Object -Unique
}
'@


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
    $PSRL = Get-Module PSReadLine -ErrorAction Ignore
    if ($PSRL.Version -ge ([version]"2.4"))
    {
        Set-PSReadlineKeyHandler -Chord Ctrl+c -Function CopyOrCancelLine
        Set-PSReadlineKeyHandler -Chord Ctrl+x -Function Cut
        Set-PSReadlineKeyHandler -Chord Ctrl+v -Function Paste
        Set-PSReadlineKeyHandler -Chord Ctrl+@ -Function MenuComplete  # Unix shells always intercept Ctrl-space - Fedora seems to map it to Ctrl-@
    }
    elseif ($PSRL)
    {
        Write-Warning "PSReadLine version is below 2.4: $($PSRL.Version)"
    }
}

# https://gist.github.com/rkeithhill/3103994447fd307b68be
Set-PSReadlineKeyHandler -Chord '(', '[', '{', '<', "'", '"', '`' -Description "Wrap selection in brackets or quotes" -ScriptBlock {
    param ($Key, $Arg)

    $L = $Key.KeyChar.ToString()
    $R = @{
        '(' = ')'
        '[' = ']'
        '{' = '}'
        '<' = '>'
        "'" = "'"
        '"' = '"'
        '`' = '`'
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

function Import-Script {
    <#
        .SYNOPSIS
        Imports script as global module. Equivalent to dot-sourcing.
    #>
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [ArgumentCompleter({
            param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

            $Files = Get-ChildItem $PSScriptRoot -Filter *.ps1 | % BaseName
            ($Files -like "$wordToComplete*"), ($Files -like "*$wordToComplete*") | Write-Output
        })]
        [string[]]$Name
    )

    if ($MyInvocation.ExpectingInput) {
        $Name = $input
    }

    foreach ($_Name in $Name) {
        [string]$Path = [IO.Path]::ChangeExtension($_Name, "ps1")  # no-op when already ps1
        if (-not (Test-Path $Path)) {$Path = Join-Path $PSScriptRoot $Path}
        $Path = Resolve-Path $Path -ErrorAction Stop

        $Importer = ". $Path; Export-ModuleMember -Function * -Variable * -Cmdlet * -Alias *"
        $ScriptBlock = [scriptblock]::Create($Importer)
        $Module = New-Module -Name $_Name -ScriptBlock $ScriptBlock

        Import-Module $Module -Global -Force
    }
}
Set-Alias ips Import-Script
