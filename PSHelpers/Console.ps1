
if (-not $PSDefaultParameterValues) {$Global:PSDefaultParameterValues = @{}}
foreach ($Kvp in ([ordered]@{
    'Out-Default:OutVariable' = '+LastOutput'
    'Get-ChildItem:Force'     = $true
}).GetEnumerator())
{
    $Global:PSDefaultParameterValues[$Kvp.Key] = $Kvp.Value
}

$Global:HostsFile = if ($IsLinux) {'/etc/hosts'} elseif ($IsMacOS) {''} else {'C:\Windows\System32\drivers\etc\hosts'}

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


Set-Alias clip Set-Clipboard
Set-Alias os Out-String
Set-Alias cm chezmoi
Set-Alias tf terraform
Set-Alias k kubectl
Set-Alias p podman
Set-Alias pc podman-compose
function pcu {param ($Path='.') Push-Location $Path; try {podman-compose up -d} finally {Pop-Location}}
function pcd {param ($Path='.') Push-Location $Path; try {podman-compose down} finally {Pop-Location}}

# Save typing out [pscustomobject]
Add-Type 'public class o : System.Management.Automation.PSObject {}' -WarningAction Ignore


$OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = [Text.Encoding]::UTF8


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
Set-PSReadlineKeyHandler -Chord Ctrl+v -Function Paste
Set-PSReadlineKeyHandler -Chord Ctrl+z -Function Undo
Set-PSReadlineKeyHandler -Chord Ctrl+y -Function Redo

function Disable-BracketedPaste
{
    # https://unix.stackexchange.com/questions/196098/copy-paste-in-xfce4-terminal-adds-0-and-1/196574#196574
    printf "\e[?2004l"
    # reset
}

function Get-PSReadlineHistory
{
    gc (Get-PSReadLineOption).HistorySavePath
}

function Test-VSCode
{
    if ($null -eq $Global:IsVSCode)
    {
        $Process = Get-Process -Id $PID
        do
        {
            $Global:IsVSCode = $Process.ProcessName -match '^node|(Code( - Insiders)?)|winpty-agent$'
            $Process = $Process.Parent
        }
        while ($Process -and -not $Global:IsVSCode)
    }
    return $Global:IsVSCode
}

if (Get-Command starship -ErrorAction SilentlyContinue)
{
    # brew install starship / choco install starship / winget install Starship.Starship
    $env:STARSHIP_CONFIG = $PSScriptRoot | Split-Path | Join-Path -ChildPath starship.toml
    starship init powershell --print-full-init | Out-String | Invoke-Expression
}
elseif (Import-Module -PassThru oh-my-posh -Global -ErrorAction SilentlyContinue)
{
    if ($PSVersionTable.PSVersion.Major -ge 7)
    {
        if ($IsLinux -and -not $env:POSH_THEMES_PATH)
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
}

Import-Module posh-git


# dotnet tab-completion
Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
    param($commandName, $wordToComplete, $cursorPosition)
    dotnet complete --position $cursorPosition "$wordToComplete" | ForEach-Object {
        [Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}

Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    $word = $wordToComplete.Replace('"', '""')
    $ast = $commandAst.ToString().Replace('"', '""')
    winget complete --word=$word --commandline $ast --position $cursorPosition | ForEach-Object {
        [Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
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

function Get-EnumValues
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateScript({$_.IsEnum})]
        [type]$Enum
    )

    process
    {
        [Enum]::GetValues($Enum) | ForEach-Object {
            [pscustomobject]@{
                Value = $_.value__
                Name  = [string]$_
            }
        }
    }
}

if ($IsLinux -and -not ($env:SSH_AUTH_SOCK -and $env:SSH_AGENT_PID))
{
    [string[]]$Agent = $(ssh-agent) -replace ';.*' | Select-Object -SkipLast 1
    $env:SSH_AUTH_SOCK = $Agent -match 'SSH_AUTH_SOCK' -replace '.*='
    $env:SSH_AGENT_PID = $Agent -match 'SSH_AGENT_PID' -replace '.*='
}
