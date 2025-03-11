
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

function ConvertFrom-Base64
{
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Base64
    )

    process
    {
        [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Base64))
    }
}

function ConvertTo-Base64
{
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$String
    )

    process
    {
        [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($String))
    }
}

function Copy-SshKey
{
    [CmdletBinding(DefaultParameterSetName = 'ByFilter')]
    param
    (
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Hostname,

        [Parameter(Mandatory, ParameterSetName = 'ByPath', Position = 1)]
        [ArgumentCompleter({Get-ChildItem ~/.ssh -File -Filter '*.pub'})]
        [string[]]$KeyFile,

        [Parameter(ParameterSetName = 'ByFilter', Position = 1)]
        [string]$Filter = $([regex]::Escape($env:USER)),

        [string]$Username,

        [switch]$IncludePrivateKey
    )

    begin
    {
        if (-not $KeyFile)
        {
            $KeyFile = (Get-Content ~/.ssh/config) -imatch 'IdentityFile' -ireplace '.*IdentityFile ' -imatch $Filter
        }

        $KeyFile = $KeyFile -replace '\.pub$'

        if ($IncludePrivateKey)
        {
            $KeyFile = $KeyFile | ForEach-Object {$_; "$_.pub"} | Write-Output
        }
        else
        {
            $KeyFile = $KeyFile -replace '$', '.pub'
        }
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
            $Dest = "$User@$_`:$UserHome/.ssh"

            scp -r $KeyFile $Dest
        }
    }
}
$PSDefaultParameterValues['Copy-SshKey:KeyFile'] = '~/.ssh/freddie_home', '~/.ssh/freddie_git'

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


function Forget-KnownHost
{
    [CmdletBinding()]
    param
    (
        [string]$Path = "~/.ssh/known_hosts",

        [Parameter(Mandatory, Position = 0)]
        [ArgumentCompleter({
            param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $Path = $fakeBoundParameters.Path
            if (-not $Path) {$Path = '~/.ssh/known_hosts'}
            $Hosts = @(Get-Content $Path) -replace '\s.*' -split ',' | sort -Unique
            @($Hosts) -like "$wordToComplete*"
        })]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string]$Hostname,

        [switch]$Check
    )

    $Content = gc $Path -ErrorAction Stop
    $Content = $Content | ? {
        $Hosts = $_ -replace '\s.*' -split ',' | sort -Unique
        # $Hosts | Write-Host
        $IsMatch = [bool]($Hosts -like $Hostname)
        -not $IsMatch -xor $Check
    }

    if ($Check)
    {
        $Content
    }
    else
    {
        $Content > $Path
    }
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

function Kill-VSCodeRemote
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, Position = 0)]
        [string]$Hostname
    )

    $Command = "'for i in `$(ps x | grep ''\.vscode-server'' | awk ''{print `$1}''); do kill -9 `$i; done'"
    ssh $Hostname bash -c $Command
}

function Activate-PyEnv
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 0)]
        [string]$Path = $(Resolve-Path .conda -ErrorAction Ignore | Select-Object -First 1)
    )

    if (-not $Path)
    {
        $Path = gci -Directory | gci -Filter pyvenv.cfg | Select-Object -First 1 | % FullName | Split-Path
        if (-not $Path)
        {
            Write-Error "No env found to activate"
            return
        }
    }

    $Mgr = if (gci $Path -Filter pyvenv.cfg) {"venv"} else {"conda"}
    if ($Mgr -eq "conda")
    {
        $Before = bash -c env
        $After = bash -c "source ~/.local/bin/miniconda/bin/activate '$Path'; env"

        $Update = Compare-Object $Before $After | ? SideIndicator -eq '=>' | % InputObject
        $Update | % {
            $k, $v = $_ -split '=', 2
            Set-Content env:\$k $v
        }
    }
    elseif ($Mgr -eq "venv")
    {
        $Script = gci ./.venv/bin/ -Filter Activate.ps1  # resolve case-sensitivity
        . $Script
    }
}

if ($IsVSCode)
{
    Activate-PyEnv -ErrorAction Ignore
    Set-Alias activate Activate-PyEnv
}

function Debug-Thunderbird
{
    [CmdletBinding()]
    param
    (
        [SupportsWildcards()]
        [ArgumentCompletions(
            "IMAP*",
            "AbOutlookDirectory",
            "AbWinHelper",
            "MAPIAddressBook",
            "compact",
            "MsgBiff",
            "MsgCopyService",
            "compact",
            "MsgFolderCache",
            "MsgPurge",
            "Compose",
            "MsgDB",
            "IMAPOffline",
            "BayesianFilter",
            "CMS",
            "IMAPAutoSync",
            "IMAP_KW",  # for logging keyword (tag) processing
            "IMAP",
            "IMAP_CS",
            "IMAPCache",
            "Import",
            "Mailbox",
            "mbox",
            "MailDirStore",
            "POP3",
            "MAPI",
            "MIME",
            "MIMECRYPT",
            "Filters"
        )]
        [string[]]$Module,

        [string]$Path = "./thunderbird.log"
    )

    $Thunderbird = Get-Command thunderbird -CommandType Application -ErrorAction Stop

    $ShouldDebug = $DebugPreference -notin ('SilentlyContinue', 'Ignore')
    $ShouldVerbose = $VerbosePreference -notin ('SilentlyContinue', 'Ignore')
    $LogLevel = if ($ShouldDebug) {5} elseif ($ShouldVerbose) {4}
    $ShouldDebug = $ShouldDebug -or $ShouldVerbose

    if ($ShouldDebug)
    {
        $ParamAst = $MyInvocation.MyCommand.ScriptBlock.Ast.Body.ParamBlock.Parameters |
            Where-Object {$_.Name.VariablePath.UserPath -eq 'Module'}
        $AttrAst = $ParamAst.Attributes |
            Where-Object {$_.TypeName.Name -eq 'ArgumentCompletions'}
        $AllModules = $AttrAst.PositionalArguments.Value -notmatch '\*'

        if (-not $AllModules)
        {
            throw [ArgumentNullException]::new(
                "Module",
                "Failed to parse valid values from AST. Probably a bug: see $($MyInvocation.MyCommand.ScriptBlock.File)."
            )
        }

        $Selected = $Module | ForEach-Object {$AllModules -like $_} | Sort-Object -Unique
        $ToDebug = $Selected -replace '$', ":$LogLevel" -join ','

        $Environment = @{
            MOZ_LOG_FILE = [IO.Path]::GetFullPath($Path)
            MOZ_LOG = "$ToDebug,timestamp"
        }
    }
    else
    {
        $Environment = @{
            MOZ_LOG_FILE = ""
            MOZ_LOG = ""
        }
    }

    Start-Process $Thunderbird.Source -Environment $Environment
}

Set-Alias thunderbird Debug-Thunderbird

Register-ArgumentCompleter -CommandName Invoke-Build.ps1 -ParameterName Task -ScriptBlock {
    param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    if (-not $Script:__BuildTasks)
    {
        $Script:__BuildTasks = @{}
    }

    $Dir = $PWD.Path
    while ($Dir -ne "/" -and -not (Get-Item -Force "$Dir/.git" -ErrorAction Ignore))
    {
        $Dir = Split-Path $Dir
    }
    if ($Dir -eq "/") {return}

    $ProjectName = Split-Path $Dir -Leaf

    $TaskNames = $Script:__BuildTasks[$ProjectName]
    if (-not $TaskNames)
    {
        $BuildScript = Get-Item "$Dir/*.build.ps1"
        $TaskNames = $BuildScript | ForEach-Object {
            $Ast = [Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$null, [ref]$null)
            $TaskAsts = $Ast.FindAll({
                param ($Ast)
                $Ast -is [System.Management.Automation.Language.CommandAst] -and
                $Ast.CommandElements[0].Value -eq "task"
            }, $true)
            $TaskAsts | ForEach-Object {$_.CommandElements[1].Value}
        } | Write-Output | Select-Object -Unique

        $Script:__BuildTasks[$ProjectName] = @($TaskNames)
    }

    ($TaskNames -like "$wordToComplete*"), ($TaskNames -like "*$wordToComplete*") | Write-Output | Select-Object -Unique
}

function logout
{
    if ($IsWindows)
    {
        logoff
        return
    }

    $SessionId = loginctl |
        select -Skip 1 |
        match "$USER\b.*\btty" |
        select -First 1 |
        % Trim |
        replace ' .*'

    loginctl kill-session $SessionId
}

Set-Alias fromj ConvertFrom-Json
Set-Alias toj ConvertTo-Json

function Set-Proxy
{
    param
    (
        [Parameter(ParameterSetName = "mitmproxy")]
        [ValidateScript({$_})]
        [switch]$mitmproxy,

        [Parameter(ParameterSetName = "off")]
        [switch]$Off,

        [Parameter(ParameterSetName = "uri", Mandatory, Position = 0, ValueFromPipeline)]
        [uri]$Proxy
    )

    if ($off)
    {
        Remove-Item Env:/HTTP_PROXY, Env:/HTTPS_PROXY -ErrorAction Ignore
        return
    }

    if ($mitmproxy)
    {
        $Proxy = "http://127.0.0.1:8080"
    }

    $env:HTTP_PROXY = $env:HTTPS_PROXY = $Proxy
}
