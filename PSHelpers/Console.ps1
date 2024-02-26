
$Global:PSDefaultParameterValues['Out-Default:OutVariable'] = '+LastOutput'
$Global:PSDefaultParameterValues['Get-ChildItem:Force'] = $true

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


Set-Alias os Out-String
Set-Alias cm chezmoi
Set-Alias tf terraform
Set-Alias k kubectl
Set-Alias p podman
Set-Alias pc podman-compose

if ($IsWindows)
{
    Set-Alias clip Set-Clipboard
}
else
{
    Set-Alias sort Sort-Object
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
Set-PSReadLineKeyHandler -Chord Ctrl-a -Function SelectAll
Set-PSReadlineKeyHandler -Chord Ctrl+z -Function Undo
Set-PSReadlineKeyHandler -Chord Ctrl+y -Function Redo

if ($IsWindows)
{
    Set-PSReadlineKeyHandler -Chord Ctrl+Spacebar -Function MenuComplete
    Set-PSReadlineKeyHandler -Chord Ctrl+c -Function CopyOrCancelLine
    Set-PSReadlineKeyHandler -Chord Ctrl+x -Function Cut
    Set-PSReadlineKeyHandler -Chord Ctrl+v -Function Paste
}
else
{
    # Unix shells always intercept Ctrl-space - Fedora seems to map it to Ctrl-@
    Set-PSReadlineKeyHandler -Chord Ctrl+@ -Function MenuComplete

    # https://github.com/PowerShell/PSReadLine/issues/1993
    if ($env:XDG_SESSION_TYPE -eq 'wayland' -and (Get-Command wl-copy -ErrorAction Ignore))
    {
        $CopyTool = 'wl-copy'
        $CopyToolArgs = '-n'
    }
    else
    {
        # xclip has weird pipe handling and hangs in pwsh, so use xsel instead
        $CopyTool = 'xsel'
        $CopyToolArgs = '-i --clipboard'
    }

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
        $Process.WaitForExit(250)
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

    $Cut = $false
    Set-PSReadLineKeyHandler -Chord Ctrl+c -Description "Copy selection, or cancel line" -ScriptBlock $Copy.GetNewClosure()
    $Cut = $true
    Set-PSReadLineKeyHandler -Chord Ctrl+x -Description "Cut selection" -ScriptBlock $Copy.GetNewClosure()

    Set-PSReadlineKeyHandler -Chord Ctrl+v -Function Paste

    Remove-Variable CopyCmd, CopyTool, CopyToolArgs, Copy, Cut -Scope Global
}

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

function Copy-SshKey
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Hostname,

        [Parameter(Mandatory)]
        [ArgumentCompleter({
            (Get-ChildItem ~/.ssh -File -Filter '*.pub') -replace '\.pub$'
        })]
        [string[]]$KeyFile,

        [string]$Username
    )

    process
    {
        $Hostname | ForEach-Object {
            $User = if ($Username)
            {
                $Username
            }
            else
            {
                $UserConfig = ssh -G $Hostname | Select-String '^user (?<User>.*)'
                if ($UserConfig)
                {
                    $UserConfig.Matches.Groups[-1].Value
                }
                else
                {
                    $env:USER
                }
            }

            $UserHome = if ($User -eq 'root') {'/root'} else {"/home/$User"}
            $Dest = "$User@$_`:$UserHome/.ssh"

            $KeyFile = $KeyFile | ForEach-Object {$_; "$_.pub"} | Write-Output
            scp -r $KeyFile $Dest
        }
    }
}

function Copy-Terminfo
{
    <#
        .DESCRIPTION
        When using kitty and SSHing to pwsh, the console can be garbled. This is caused by TERM
        being set to 'xterm-kitty' on the remote host, but kitty not having a terminfo entry. This
        can be worked around with `$env:TERM = 'xterm-256color'; ssh <host>`, but the actual fix
        is to copy over the kitty declaration to the remote host.
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Hostname,

        [string]$Username,

        [switch]$Force
    )

    begin
    {
        if ($env:TERM -ne 'xterm-kitty' -and -not $Force)
        {
            Write-Warning "TERM is not 'xterm-kitty'; use -Force to override"
            return
        }
        $Src = Resolve-Path $HOME/.terminfo
    }

    process
    {
        $Hostname | ForEach-Object {
            $User = if ($Username)
            {
                $Username
            }
            else
            {
                $UserConfig = ssh -G $Hostname | Select-String '^user (?<User>.*)'
                if ($UserConfig)
                {
                    $UserConfig.Matches.Groups[-1].Value
                }
                else
                {
                    $env:USER
                }
            }

            $UserHome = if ($User -eq 'root') {'/root'} else {"/home/$User"}
            $Dest = "$User@$_`:$UserHome"

            scp -r $Src $Dest
        }
    }
}

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

function Sync-Chezmoi
{
    param
    (
        [switch]$Force,
        [switch]$Stash = $true
    )

    $CM = chezmoi data | ConvertFrom-Json | % chezmoi

    $Pattern = '^diff (--\w+ )*a/(?<Path>.*) b/'
    $Lines = (cm diff) -match $Pattern
    $Paths = $Lines | ForEach-Object {
        $null = $_ -match $Pattern
        $Matches.Path
    }

    $Modified = $null
    Push-Location $CM.sourceDir
    try
    {
        $Modified = (git status -s) -replace '^...'
        if ('.chezmoitemplates/profile.ps1' -in $Modified)
        {
            git stash push '.chezmoitemplates/profile.ps1' -m "Sync-Chezmoi: stash profile.ps1"
        }
    }
    finally
    {
        Pop-Location
    }

    $Source = $PROFILE.CurrentUserAllHosts
    $Dest = Join-Path $CM.sourceDir '.chezmoitemplates/profile.ps1'
    (Get-Content -Raw $Source).Replace($CM.sourceDir, '{{ .chezmoi.sourceDir }}', [System.StringComparison]::OrdinalIgnoreCase) > $Dest
}

if ((-not $IsWindows) -and (Get-Command ip -CommandType Application -ErrorAction Ignore))
{
    function Get-NetIpAddress
    {
        [CmdletBinding()]
        param
        (
            [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
            [string[]]$Name
        )

        begin
        {
            Update-TypeData -Force -TypeName InetAddress -DefaultDisplayPropertySet Name, IpAddress, Prefix, Scope
            $Pattern = 'inet(6?) (?<IpAddress>\S+)/(?<Prefix>\d+) (brd (?<Broadcast>\S+) )?scope (?<Scope>.*)'
        }

        process
        {
            $Name | ForEach-Object {
                $IpText = ip address show $_ | Out-String
                $Links = $IpText -split '(?<=^|\n)(?=\d+:)' | ForEach-Object Trim | Where-Object Length
                $Links | ForEach-Object {
                    $Head1, $Head2, $Addrs = $_ -split '\n', 3
                    $Index, $Name, $IfProperties = $Head1 -split ': ', 3
                    $Hardware = $Head2 -replace '^\s+'

                    $Addrs -split '\n(?=    inet)' | ForEach-Object Trim | Where-Object Length | ForEach-Object {
                        $Head, $IpAddressProperties = $_ -split '\n', 2 | ForEach-Object Trim
                        if ($Head -match $Pattern)
                        {
                            $IpAddress = $Matches.IpAddress
                            $Prefix    = $Matches.Prefix
                            $Broadcast = $Matches.Broadcast
                            $Scope     = $Matches.Scope -split ' '
                        }
                        else
                        {
                            Write-Error "Failed to parse '$Head'"
                            return
                        }

                        [pscustomobject]@{
                            PSTypeName          = 'InetAddress'
                            Index               = $Index
                            Name                = $Name
                            IfProperties        = $IfProperties
                            Hardware            = $Hardware
                            IpAddress           = [ipaddress]$IpAddress
                            Prefix              = $Prefix
                            Scope               = $Scope
                            IpAddressProperties = $IpAddressProperties.Trim()
                        }
                    }
                }
            }
        }
    }
    Set-Alias gnip Get-NetIpAddress
}

function Start-Emacs
{
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$File,

        [Parameter(ValueFromRemainingArguments)]
        [string[]]$ArgumentList = '--create-frame'
    )

    begin
    {
        if (-not (Get-Process emacs -ErrorAction Ignore | where CommandLine -match --daemon))
        {
            setsid -fw emacs --daemon
        }
    }

    process
    {
        if ($File)
        {
            $File = $File -replace '^~', $env:HOME
            $ArgumentList = [System.IO.Path]::GetFullPath($File), $ArgumentList | Write-Output
        }
        setsid -f emacsclient $ArgumentList
    }
}
Set-Alias emacs Start-Emacs

if ($IsLinux -and (Get-Command dnf5 -CommandType Application -ErrorAction Ignore))
{
    Set-Alias dnf dnf5
}
