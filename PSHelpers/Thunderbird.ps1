function Debug-Thunderbird
{
    <#
        X11 options
        --display=DISPLAY  X display to use
        --sync             Make X calls synchronous
        --g-fatal-warnings Make all warnings fatal

        Thunderbird options
        -h or --help       Print this message.
        -v or --version    Print Thunderbird version.
        --full-version     Print Thunderbird version, build and platform build ids.
        -P <profile>       Start with <profile>.
        --profile <path>   Start with profile at <path>.
        --migration        Start with migration wizard.
        --ProfileManager   Start with ProfileManager.
        --no-remote        Do not accept or send remote commands; implies
                            --new-instance.
        --new-instance     Open new instance, not a new window in running instance.
        --safe-mode        Disables extensions and themes for this session.
        --allow-downgrade  Allows downgrading a profile.
        --MOZ_LOG=<modules> Treated as MOZ_LOG=<modules> environment variable,
                            overrides it.
        --MOZ_LOG_FILE=<file> Treated as MOZ_LOG_FILE=<file> environment variable,
                            overrides it. If MOZ_LOG_FILE is not specified as an
                            argument or as an environment variable, logging will be
                            written to stdout.
        --headless         Run without a GUI.
        --dbus-service <launcher>  Run as DBus service for org.freedesktop.Application and
                                    set a launcher (usually /usr/bin/appname script) for it.
        -compose [ <options> ] Compose a mail or news message. Options are specified
                            as string "option='value,...',option=value,..." and
                            include: from, to, cc, bcc, newsgroups, subject, body,
                            message (file), attachment (file), format (html | text).
                            Example: "to=john@example.com,subject='Dinner tonight?'"
        --jsconsole        Open the Browser Console.
        --devtools         Open DevTools on initial load.
        --jsdebugger [<path>] Open the Browser Toolbox. Defaults to the local build
                            but can be overridden by a firefox path.
        --wait-for-jsdebugger Spin event loop until JS debugger connects.
                            Enables debugging (some) application startup code paths.
                            Only has an effect when `--jsdebugger` is also supplied.
        --start-debugger-server [ws:][ <port> | <path> ] Start the devtools server on
                            a TCP port or Unix domain socket path. Defaults to TCP port
                            6000. Use WebSocket protocol if ws: prefix is specified.
        --marionette       Enable remote control server.
        --remote-debugging-port [<port>] Start the Firefox Remote Agent,
                            which is a low-level remote debugging interface used for WebDriver
                            BiDi and CDP. Defaults to port 9222.
        --remote-allow-hosts <hosts> Values of the Host header to allow for incoming requests.
                            Please read security guidelines at https://firefox-source-docs.mozilla.org/remote/Security.html
        --remote-allow-origins <origins> Values of the Origin header to allow for incoming requests.
                            Please read security guidelines at https://firefox-source-docs.mozilla.org/remote/Security.html
        -mail              Go to the mail tab.
        -addressbook       Go to the address book tab.
        -calendar          Go to the calendar tab.
        -options           Go to the settings tab.
        -file              Open the specified email file or ICS calendar file.
        -setDefaultMail    Set this app as the default mail client.
        -keymanager        Open the OpenPGP Key Manager.
    #>
    [CmdletBinding(PositionalBinding = $false, DefaultParameterSetName = "Default")]
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

        [string]$Path = "./thunderbird.log",

        [Parameter(ParameterSetName = 'ByProfile')]
        [string]$Profile,

        [switch]$ProfileManager,

        [Parameter(DontShow, ValueFromRemainingArguments)]
        [string[]]$TArgs
    )

    if ($PSBoundParameters.ContainsKey("Profile")) {$TArgs = @("-P", $Profile) + $TArgs}

    if ($ProfileManager) {$TArgs = @("-ProfileManager") + $TArgs}

    $Thunderbird = Get-Command thunderbird -CommandType Application -ErrorAction Stop

    $ShouldDebug = $DebugPreference -notin ('SilentlyContinue', 'Ignore')
    $ShouldVerbose = $VerbosePreference -notin ('SilentlyContinue', 'Ignore')
    $LogLevel = if ($ShouldDebug) {5} elseif ($ShouldVerbose) {4}
    $ShouldDebug = $ShouldDebug -or $ShouldVerbose

    if ($ShouldDebug)
    {
        $ParamAsts = $MyInvocation.MyCommand.ScriptBlock.Ast.Body.ParamBlock.Parameters
        $ParamAst = $ParamAsts |
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

    Start-Process $Thunderbird.Source -Environment $Environment -ArgumentList $TArgs
}

Register-ArgumentCompleter -CommandName Debug-Thunderbird -ParameterName Profile -ScriptBlock {
    param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    $Names = Get-ThunderbirdProfile | % Name
    (@($Names) -like "$wordToComplete*"), (@($Names) -like "*$wordToComplete*") | Write-Output | Select-Object -Unique
}

Set-Alias thunderbird Debug-Thunderbird

function Test-ThunderbirdClosed
{
    $Platform = [environment]::OSVersion.Platform
    if ($Platform -match 'Win')
    {
        return -not (Get-Process thunderbird -ErrorAction Ignore)
    }
    throw [NotImplementedException]::new("Not tested on $Platform")
}

function Get-ThunderbirdProfileBase
{
    $ProfileBase = if ($IsLinux) {"~/.thunderbird"} elseif ($IsMacOS) {"~/Library/Thunderbird"} else {Join-Path $env:APPDATA Thunderbird}
    Resolve-Path $ProfileBase -ErrorAction Stop
}

class ThunderbirdProfile
{
    [string]$Name
    [string]$Path
    [bool]$IsDefault

    ThunderbirdProfile ([string]$Name, [string]$Path, [bool]$IsDefault)
    {
        $this.Name = $Name
        $this.Path = $Path
        $this.IsDefault = $IsDefault
    }

    [string] ToString ()
    {
        return $this.Name
    }
}

function Get-ThunderbirdProfile
{
    [CmdletBinding()]
    param
    (
        [ArgumentCompleter({
            param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $Names = Get-ThunderbirdProfile | % Name
            (@($Names) -like "$wordToComplete*"), (@($Names) -like "*$wordToComplete*") | Write-Output | Select-Object -Unique
        })]
        [string]$Name
    )

    $Default = $null

    $ProfileBase = Get-ThunderbirdProfileBase
    $ProfileIni = Join-Path $ProfileBase profiles.ini

    $Chunks = (Get-Content -Raw $ProfileIni) -split "(?<=\n)(?=\[)"
    $Profiles = $Chunks | % {
        $Acc = @{}
        $_ -split "\n" -match "=" | % {
            $Key, $Value = $_ -split "="
            $Acc[$Key] = $Value
        }
        if ($Acc.Path) {
            $Acc
        } else {
            $Default = $Acc.Default
        }
    }
    $Profiles = $Profiles | % {
        $Path = Join-Path $ProfileBase $_.Path
        [ThunderbirdProfile]::new(
            $_.Name, $Path, $_.Path -eq $Default
        )
    }
    if ($Name) {
        $Profiles | ? Name -like $Name
    } else {
        $Profiles
    }
}
