
$Global:PSDefaultParameterValues['ConvertTo-*:Depth'] = 8

function Get-EnumValues
{
    [CmdletBinding(DefaultParameterSetName = "ByType")]
    param
    (
        [Parameter(ParameterSetName = "ByType", Mandatory, Position = 0, ValueFromPipeline)]
        [ValidateScript({$_.IsEnum})]
        [type]$Enum,

        [Parameter(ParameterSetName = "FromInstance", Mandatory, Position = 0, ValueFromPipeline)]
        [enum]$InputObject
    )

    process
    {
        if ($PSCmdlet.ParameterSetName -eq "FromInstance") {$Enum = $InputObject.GetType()}

        [Enum]::GetValues($Enum) | ForEach-Object {
            [pscustomobject]@{
                Value = $_.value__
                Name  = [string]$_
            }
        }
    }
}
Set-Alias enumvals Get-EnumValues

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
Set-Alias fromy ConvertFrom-Yaml
Set-Alias toy ConvertTo-Yaml
Set-Alias fromb64 ConvertFrom-Base64
Set-Alias tob64 ConvertTo-Base64

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

function Read-Journal
{
    [CmdletBinding()]
    param
    (
        [string]$Unit,

        [ValidateRange(1, [int]::MaxValue)]
        [int]$Count,

        [ValidateSet("short", "short-precise", "short-iso", "short-iso-precise", "short-full", "short-monotonic", "short-unix", "verbose", "export", "json", "json-pretty", "json-sse", "json-seq", "cat", "with-unit")]
        [string]$Format = "short-precise",

        # generate with: journalctl --fields
        [ValidateSet("CODE_LINE", "_COMM", "INITRD_USEC", "_AUDIT_ID", "DISK_AVAILABLE", "OPERATION", "UNIT", "_AUDIT_FIELD_SUCCESS", "PRIORITY", "SYSLOG_FACILITY", "_UID", "_AUDIT_TYPE", "_AUDIT_FIELD_SCONTEXT", "TID", "JOB_TYPE", "_AUDIT_FIELD_TABLE", "LEADER", "AUDIT_FIELD_DEFAULT_CONTEXT", "NM_LOG_DOMAINS", "DISK_KEEP_FREE", "JOB_RESULT", "_TTY", "REF", "INVOCATION_ID", "_SYSTEMD_USER_UNIT", "AUDIT_FIELD_NEW_LEVEL", "AUDIT_FIELD_UNIT", "_AUDIT_FIELD_A1", "SEAT_ID", "AUDIT_FIELD_HOSTNAME", "JOURNAL_NAME", "_UDEV_DEVNODE", "_AUDIT_FIELD_TCONTEXT", "CODE_FILE", "_SYSTEMD_SLICE", "AVAILABLE_PRETTY", "_FSUID", "_AUDIT_FIELD_ENTRIES", "_SOURCE_MONOTONIC_TIMESTAMP", "SESSION_ID", "_EXE", "AVAILABLE", "_AUDIT_FIELD_INO", "_AUDIT_FIELD_AUDIT_ENABLED", "_AUDIT_FIELD_PERMISSIVE", "AUDIT_FIELD_ACCT", "CURRENT_USE", "_AUDIT_FIELD_FAMILY", "_SYSTEMD_USER_SLICE", "CURRENT_USE_PRETTY", "_AUDIT_SESSION", "INSTALLATION", "_STREAM_ID", "MESSAGE_ID", "DBUS_BROKER_LOG_DROPPED", "_MACHINE_ID", "AUDIT_FIELD_OLD_LEVEL", "USER_UNIT", "_AUDIT_FIELD_SGID", "THREAD_ID", "_AUDIT_FIELD_TCLASS", "_AUDIT_FIELD_SYSCALL", "_CMDLINE", "DISK_AVAILABLE_PRETTY", "_RUNTIME_SCOPE", "LIMIT_PRETTY", "SYSLOG_PID", "_AUDIT_FIELD_AUDIT_PID", "_AUDIT_FIELD_SUID", "_FSGID", "CONFIG_FILE", "_AUDIT_TYPE_NAME", "GLIB_DOMAIN", "_SYSTEMD_OWNER_UID", "CODE_FUNC", "_AUDIT_FIELD_ARCH", "_SYSTEMD_SESSION", "USER_ID", "_GID", "KERNEL_USEC", "_AUDIT_FIELD_NAME", "AUDIT_FIELD_COMM", "REALMD_OPERATION", "REMOTE", "_PID", "LIMIT", "ERRNO", "_AUDIT_FIELD_KEY", "OBJECT_PID", "_EGID", "_KERNEL_DEVICE", "_UDEV_SYSNAME", "OLD_COMMIT", "_SYSTEMD_UNIT", "_AUDIT_FIELD_PROG_ID", "MEMORY_SWAP_PEAK", "COMMIT", "FLATPAK_VERSION", "INTERFACE", "_AUDIT_LOGINUID", "MAX_USE", "_KERNEL_SUBSYSTEM", "_AUDIT_FIELD_RES", "_PPID", "_CAP_EFFECTIVE", "_SELINUX_CONTEXT", "AUDIT_FIELD_ADDR", "TIMESTAMP_BOOTTIME", "JOB_ID", "AUDIT_FIELD_TERMINAL", "_AUDIT_FIELD_OLD", "_AUDIT_FIELD_A2", "USER_INVOCATION_ID", "_TRANSPORT", "_AUDIT_FIELD_OP", "AUDIT_FIELD_EXE", "JOURNAL_PATH", "TAINT", "TIMESTAMP_MONOTONIC", "MESSAGE", "_SYSTEMD_INVOCATION_ID", "_AUDIT_FIELD_A3", "CONFIG_LINE", "_AUDIT_FIELD_EXIT", "_AUDIT_FIELD_DEV", "_EUID", "MEMORY_PEAK", "NM_DEVICE", "AUDIT_FIELD_GRANTORS", "SYSLOG_IDENTIFIER", "_AUDIT_FIELD_ITEMS", "_SOURCE_REALTIME_TIMESTAMP", "SYSLOG_TIMESTAMP", "_HOSTNAME", "AUDIT_FIELD_RES", "AUDIT_FIELD_OP", "DISK_KEEP_FREE_PRETTY", "_BOOT_ID", "_AUDIT_FIELD_A0", "SYSLOG_RAW", "GLIB_OLD_LOG_API", "USERSPACE_USEC", "_SYSTEMD_CGROUP", "CPU_USAGE_NSEC", "URL", "MAX_USE_PRETTY", "NM_LOG_LEVEL", "DBUS_BROKER_METRICS_DISPATCH_MIN", "OBJECT_SYSTEMD_SLICE", "OBJECT_SYSTEMD_USER_UNIT", "TOPIC", "SRC", "DBUS_BROKER_METRICS_DISPATCH_STDDEV", "DBUS_BROKER_SENDER_SECURITY_LABEL", "CHECKSUM_ALGORITHM", "SETYPE", "DEST", "DBUS_BROKER_LAUNCH_SERVICE_UNIT", "OBJECT_AUDIT_SESSION", "DBUS_BROKER_MESSAGE_MEMBER", "AUDIT_FIELD_GPG_RES", "SEUSER", "DBUS_BROKER_SENDER_WELL_KNOWN_NAME_0", "GATHER_TIMEOUT", "SHUTDOWN", "AUDIT_FIELD_ROOT_DIR", "PATH", "DBUS_BROKER_METRICS_DISPATCH_COUNT", "OBJECT_SYSTEMD_USER_SLICE", "DBUS_BROKER_MESSAGE_INTERFACE", "AUDIT_FIELD_KEY_ENFORCE", "SSSD_PRG_NAME", "DBUS_BROKER_POLICY_TYPE", "NM_CONNECTION", "RECURSE", "GATHER_SUBSET", "DBUS_BROKER_LAUNCH_SERVICE_ID", "AUDIT_FIELD_CIPHER", "SCOPE", "DBUS_BROKER_MESSAGE_SERIAL", "OBJECT_SELINUX_CONTEXT", "GET_CHECKSUM", "AUDIT_FIELD_SW_TYPE", "DBUS_BROKER_TRANSMIT_ACTION", "DBUS_BROKER_LAUNCH_SERVICE_NAME", "STATE", "FILTER", "OBJECT_UID", "DBUS_BROKER_LAUNCH_BUS_ERROR_MESSAGE", "GET_MIME", "DBUS_BROKER_LAUNCH_ARG0", "DBUS_BROKER_MESSAGE_TYPE", "DBUS_BROKER_MESSAGE_UNIX_FDS", "DBUS_BROKER_LAUNCH_SERVICE_USER", "MODE", "SSSD_DOMAIN", "ACCESS_TIME", "AUDIT_FIELD_SW", "AUDIT_FIELD_CWD", "DBUS_BROKER_SENDER_UNIQUE_NAME", "AUDIT_FIELD_KIND", "OBJECT_GID", "DBUS_BROKER_MESSAGE_PATH", "OBJECT_AUDIT_LOGINUID", "SEROLE", "DBUS_BROKER_METRICS_DISPATCH_MAX", "MODIFICATION_TIME_FORMAT", "ACTION", "DBUS_BROKER_LAUNCH_SERVICE_UID", "AUDIT_FIELD_KSIZE", "AUDIT_FIELD_MAC", "OPERATOR", "DBUS_BROKER_LAUNCH_SERVICE_PATH", "AUDIT_FIELD_LADDR", "AUDIT_FIELD_FP", "AUDIT_FIELD_PFS", "_LINE_BREAK", "DBUS_BROKER_MESSAGE_SIGNATURE", "FACT_PATH", "DAEMON_REEXEC", "SELEVEL", "DBUS_BROKER_LAUNCH_SERVICE_INSTANCE", "ENABLED", "AUDIT_FIELD_LPORT", "FORCE", "ACCESS_TIME_FORMAT", "OWNER", "DBUS_BROKER_RECEIVER_SECURITY_LABEL", "UNSAFE_WRITES", "DBUS_BROKER_METRICS_DISPATCH_AVG", "AUDIT_FIELD_CMD", "MODIFICATION_TIME", "AUDIT_FIELD_ID", "OBJECT_CMDLINE", "MODULE", "MASKED", "AUDIT_FIELD_SUID", "OBJECT_SYSTEMD_UNIT", "GROUP", "DBUS_BROKER_LAUNCH_BUS_ERROR_NAME", "OBJECT_SYSTEMD_OWNER_UID", "AUDIT_FIELD_DIRECTION", "NO_BLOCK", "GET_ATTRIBUTES", "DAEMON_RELOAD", "AUDIT_FIELD_SPID", "ATTRIBUTES", "OBJECT_SYSTEMD_INVOCATION_ID", "OBJECT_EXE", "FOLLOW", "DBUS_BROKER_RECEIVER_UNIQUE_NAME", "_AUDIT_FIELD_CAPABILITY", "AUDIT_FIELD_RPORT", "OBJECT_SYSTEMD_CGROUP", "DBUS_BROKER_MESSAGE_DESTINATION", "OBJECT_COMM", "OBJECT_CAP_EFFECTIVE", "NAME", "BUGFIX", "BACKUP", "THROTTLE", "STRIP_EMPTY_ENDS", "INSTALLROOT", "IP_RESOLVE", "ENABLE_PLUGIN", "CREATES", "DISABLE_PLUGIN", "SKIP_BROKEN", "CACHEONLY", "PROTECT", "ALLOW_DOWNGRADE", "GPGCHECK", "FAILOVERMETHOD", "EXECUTABLE", "UI_REPOID_VARS", "DIRECTORY_MODE", "ALLOWERASING", "ENABLEGROUPS", "INCLUDE", "PASSWORD", "AUTOREMOVE", "VALIDATE", "FILE", "PROXY", "S3_ENABLED", "AUTO_INSTALL_MODULE_DEPS", "HTTP_CACHING", "INSERTBEFORE", "INSTALL_WEAK_DEPS", "ASYNC", "REMOTE_SRC", "FINGERPRINT", "INSTALL_REPOQUERY", "NOBEST", "CREATE", "DISABLEREPO", "SECURITY", "RETRIES", "KEEPALIVE", "VALIDATE_CERTS", "INSERTAFTER", "GPGKEY", "CHDIR", "CHECKSUM", "REMOVES", "SKIP_IF_UNAVAILABLE", "SSLCLIENTCERT", "TIMEOUT", "CONTENT", "METALINK", "KEY", "REPO_GPGCHECK", "STDIN_ADD_NEWLINE", "PROXY_PASSWORD", "BASEURL", "SSLVERIFY", "LINE", "DELTARPM_METADATA_PERCENTAGE", "DESCRIPTION", "GPGCAKEY", "SSL_CHECK_CERT_PERMISSIONS", "LOCAL_FOLLOW", "MIRRORLIST", "ARGV", "BANDWIDTH", "MIRRORLIST_EXPIRE", "SSLCACERT", "PROXY_USERNAME", "REPOSDIR", "ENABLEREPO", "LIST", "DOWNLOAD_ONLY", "EXPAND_ARGUMENT_VARS", "MODULE_HOTFIXES", "LOCK_TIMEOUT", "COST", "DELTARPM_PERCENTAGE", "USERNAME", "METADATA_EXPIRE_FILTER", "SSLCLIENTKEY", "REGEXP", "DISABLE_GPG_CHECK", "DOWNLOAD_DIR", "UPDATE_ONLY", "INCLUDEPKGS", "DISABLE_EXCLUDES", "FIRSTMATCH", "CONF_FILE", "UPDATE_CACHE", "SEARCH_STRING", "EXCLUDE", "BACKREFS", "RELEASEVER", "KEEPCACHE", "STDIN", "METADATA_EXPIRE", "SSH_KEY_COMMENT", "PASSWORD_LOCK", "UPDATE_PASSWORD", "PROFILE", "GROUPS", "AUTHORIZATION", "SKELETON", "EXPIRES", "HIDDEN", "PASSWORD_EXPIRE_MIN", "SSH_KEY_FILE", "COMMENT", "AUDIT_FIELD_GRP", "MOVE_HOME", "CREATE_HOME", "PASSWORD_EXPIRE_WARN", "SSH_KEY_BITS", "UID", "HOME", "PASSWORD_EXPIRE_MAX", "GENERATE_SSH_KEY", "SSH_KEY_PASSPHRASE", "UMASK", "APPEND", "ROLE", "REMOVE", "NON_UNIQUE", "SHELL", "LOCAL", "SSH_KEY_TYPE", "SYSTEM", "LOGIN_CLASS", "CONTAINS", "AGE_STAMP", "READ_WHOLE_FILE", "DEPTH", "FILE_TYPE", "PATHS", "PATTERNS", "USE_REGEX", "EXACT_MODE", "AGE", "EXCLUDES", "SIZE", "IO_BUFFER_SIZE", "DECOMPRESS", "CLIENT_CERT", "CIPHERS", "METHOD", "HEADERS", "OSTREE_REMOTE", "COPY", "URL_PASSWORD", "HTTP_AGENT", "URL_USERNAME", "USE_PROXY", "USE_GSSAPI", "DECRYPT", "UNREDIRECTED_HEADERS", "EXTRA_OPTS", "OSTREE_GPG", "KEEP_NEWER", "USE_NETRC", "LIST_FILES", "NO_DEPENDENCIES", "CLIENT_KEY", "TMP_DEST", "FORCE_BASIC_AUTH", "OSTREE_SIGN", "OSTREE_SECONDS", "OSTREE_XFER_SIZE", "AUDIT_FIELD_LSM", "XMLSTRING", "INPUT_TYPE", "NAMESPACES", "AUDIT_FIELD_SEQNO", "ATTRIBUTE", "AUDIT_FIELD_SAUID", "PRINT_MATCH", "VALUE", "STRIP_CDATA_TAGS", "ADD_CHILDREN", "_AUDIT_FIELD_LSM", "XPATH", "PRETTY_PRINT", "COUNT", "SET_CHILDREN", "AUDIT_FIELD_TGLOB", "_AUDIT_FIELD_LIST", "AUDIT_FIELD_FTYPE", "AUDIT_FIELD_RESRC", "AUDIT_FIELD_TCONTEXT", "PROBLEM_COUNT", "PROBLEM_BINARY", "PROBLEM_UUID", "PROBLEM_CRASH_FUNCTION", "_UDEV_DEVLINK", "PROBLEM_DIR", "UNIT_RESULT", "PROBLEM_PID", "DEVICE", "PROBLEM_REASON", "_AUDIT_FIELD_SADDR", "PROBLEM_REPORT", "_AUDIT_FIELD_SIG", "SLEEP", "EXIT_CODE", "EXIT_STATUS", "COMMAND", "VIRTUALENV", "_AUDIT_FIELD_OLD_PROM", "VIRTUALENV_COMMAND", "IO_METRIC_WRITE_OPERATIONS", "VIRTUALENV_SITE_PACKAGES", "IO_METRIC_WRITE_BYTES", "_AUDIT_FIELD_PROM", "REQUIREMENTS", "VERSION", "EXTRA_ARGS", "EDITABLE", "IO_METRIC_READ_OPERATIONS", "IO_METRIC_READ_BYTES", "VIRTUALENV_PYTHON", "DNS4", "FORWARDDELAY", "HELLOTIME", "RUNNER_FAST_RATE", "MIIMON", "STP", "DNS6_SEARCH", "AUDIT_FIELD_ACL", "HAIRPIN", "ROUTE_METRIC4", "DOWNDELAY", "AUDIT_FIELD_RDEV", "DNS6_IGNORE_AUTO", "INGRESS", "AUDIT_FIELD_NET", "IFNAME", "GSM", "AUDIT_FIELD_OLD_DISK", "WIFI", "ZONE", "SLAVEPRIORITY", "NEVER_DEFAULT4", "VXLAN_ID", "GW6", "XMIT_HASH_POLICY", "LIBVIRT_DOMAIN", "ARP_IP_TARGET", "LIBVIRT_SOURCE", "GW4", "LIBVIRT_CODE", "AUDIT_FIELD_PATH", "VXLAN_LOCAL", "AUDIT_FIELD_DEVICE", "AUDIT_FIELD_OLD_MEM", "CONN_NAME", "WIREGUARD", "ROUTES6", "ROUTE_METRIC6", "AUDIT_FIELD_CLASS", "UPDELAY", "IP_TUNNEL_REMOTE", "AUDIT_FIELD_OLD_NET", "AUDIT_FIELD_OLD_VCPU", "AUDIT_FIELD_NEW_VCPU", "ROUTES4", "PRIMARY", "ADDR_GEN_MODE6", "SSID", "AUDIT_FIELD_OLD_CHARDEV", "AUDIT_FIELD_NEW_DISK", "PATH_COST", "AUDIT_FIELD_MODEL", "VXLAN_REMOTE", "AUDIT_FIELD_VM", "SLAVE_TYPE", "MAXAGE", "WIFI_SEC", "FLAGS", "MAY_FAIL4", "AGEINGTIME", "AUDIT_FIELD_IMG_CTX", "AUDIT_FIELD_UUID", "DNS6", "MTU", "MASTER", "ARP_INTERVAL", "AUDIT_FIELD_VM_CTX", "METHOD4", "DNS4_OPTIONS", "GW6_IGNORE_AUTO", "AUDIT_FIELD_BUS", "EGRESS", "AUDIT_FIELD_VIRT", "ROUTES4_EXTENDED", "AUDIT_FIELD_REASON", "ROUTES6_EXTENDED", "DNS4_IGNORE_AUTO", "AUDIT_FIELD_VM_PID", "VPN", "TYPE", "DNS4_SEARCH", "TRANSPORT_MODE", "IP_TUNNEL_LOCAL", "AUDIT_FIELD_NEW_NET", "AUDIT_FIELD_MAJ", "IP_TUNNEL_DEV", "AUDIT_FIELD_NEW_MEM", "ROUTING_RULES4", "IP_TUNNEL_INPUT_KEY", "IP6", "DHCP_CLIENT_ID", "IP_PRIVACY6", "DNS6_OPTIONS", "IP4", "IP_TUNNEL_OUTPUT_KEY", "MAC", "RUNNER_HWADDR_POLICY", "GW4_IGNORE_AUTO", "VLANDEV", "MACVLAN", "RUNNER", "AUDIT_FIELD_CATEGORY", "AUDIT_FIELD_NEW_CHARDEV", "VLANID", "METHOD6", "IGNORE_UNSUPPORTED_SUBOPTIONS", "AUTOCONNECT", "AUDIT_FIELD_CGROUP", "N_RESTARTS", "COREDUMP_TIMESTAMP", "COREDUMP_PACKAGE_NAME", "COREDUMP_GID", "COREDUMP_PROC_STATUS", "COREDUMP_FILENAME", "PODMAN_EVENT", "PODMAN_TIME", "COREDUMP_CGROUP", "COREDUMP_PROC_AUXV", "COREDUMP_PROC_LIMITS", "COREDUMP_ENVIRON", "COREDUMP_OPEN_FDS", "COREDUMP_RLIMIT", "COREDUMP_UID", "COREDUMP_USER_UNIT", "COREDUMP_PROC_MOUNTINFO", "COREDUMP_PROC_MAPS", "COREDUMP_PACKAGE_VERSION", "COREDUMP_PACKAGE_JSON", "PODMAN_TYPE", "COREDUMP_UNIT", "COREDUMP_CMDLINE", "COREDUMP_PROC_CGROUP", "COREDUMP_SLICE", "COREDUMP_ROOT", "COREDUMP_SIGNAL_NAME", "COREDUMP_PID", "COREDUMP_HOSTNAME", "COREDUMP_SIGNAL", "COREDUMP_COMM", "COREDUMP_CWD", "COREDUMP_EXE", "COREDUMP_OWNER_UID", "SRC_RANGE", "SET_DSCP_MARK_CLASS", "TCP_FLAGS", "LIMIT_BURST", "FLUSH", "DST_RANGE", "IP_VERSION", "RULE_NUM", "SET_COUNTERS", "CHAIN_MANAGEMENT", "TO_SOURCE", "MATCH_SET", "POLICY", "MATCH_SET_FLAGS", "DESTINATION_PORTS", "MATCH", "DESTINATION", "SOURCE_PORT", "WAIT", "GATEWAY", "IN_INTERFACE", "SET_DSCP_MARK", "LOG_LEVEL", "REJECT_WITH", "DESTINATION_PORT", "OUT_INTERFACE", "TABLE", "SYN", "ICMP_TYPE", "TO_DESTINATION", "UID_OWNER", "FRAGMENT", "TO_PORTS", "LOG_PREFIX", "GOTO", "CHAIN", "CTSTATE", "PROTOCOL", "SOURCE", "GID_OWNER", "JUMP", "NUMERIC", "DBUS_BROKER_LAUNCH_ARG1", "BOLT_LOG_CONTEXT", "BOLT_VERSION", "BOLT_TOPIC", "AUDIT_FIELD_NEW_FS", "_AUDIT_FIELD_PATH", "AUDIT_FIELD_OLD_FS")]
        [string[]]$Fields,

        [switch]$NoSudo,

        [ValidateSet("system", "user", "*", "dmesg")]
        [string]$Journal,

        $Since,

        $Until,

        [Parameter(ParameterSetName = "boot")]
        [ValidateRange(-65535, 0)]
        [int]$Boot,

        [string]$Pattern,

        [switch]$Follow
    )

    if ($Boot) {
        if ($Journal -and $Journal -ne "dmesg") {
            throw [System.Management.Automation.ParameterBindingException]::new("-Boot not compatible with -Journal [system|user]")
        }
        $Journal = "dmesg"
    }

    $_args = @()

    if ("system", "user" -eq $Journal) {
        $_args += "--$Journal"
    } elseif ($Journal -eq "dmesg") {
        $_args += "-k"
    }

    if ($Unit)
    {
        $param = if ($Journal -eq "user") {"user-unit"} else {"unit"}
        $_args += "--$param=$Unit"
    }
    if ($Count) {$_args += "--lines=$Count"}
    if ($Format) {$_args += "--output=$Format"}
    if ($Fields) {$_args += "--output-fields=$($Fields -join ',')"}
    if ($Boot) {$_args += "--boot=$Boot"}
    if ($Pattern) {$_args += "--grep=$Pattern"}
    if ($Follow) {$_args += "--follow"}

    foreach ($Key in "Since", "Until")
    {
        $Value = $PSBoundParameters[$Key]
        if ($null -eq $Value) {continue}

        if ($Value -is [int]) {
            $Value = [timespan]::new(0, 0, [Math]::Abs($Value))
        } else {
            try {$null = [timespan]::TryParse($Value, [ref]$Value)} catch {}
        }

        if ($Value -is [timespan]) {
            $Value = [datetime]::Now.Add(-$Value)
        }

        if ($Value -is [datetime]) {
            $Value = $Value.ToString("s")
        } else {
            $Value = $Value -replace '(\s+ago)?\s*$', " ago"
        }

        $_args += "--$($Key.ToLower())=$Value"
    }

    Write-Verbose "journalctl $_args"

    if ($NoSudo)
    {
        journalctl @_args
    }
    else
    {
        sudo journalctl @_args
    }
}

function Read-IniConf {

    [CmdletBinding(DefaultParameterSetName = "NoMapper")]
    param
    (
        [Parameter(ValueFromPipeline)]
        [string]$InputObject,

        [switch]$AsHashtable,

        [Parameter(ParameterSetName = "Mapper")]
        [scriptblock]$ValueMapper,

        [Parameter(ParameterSetName = "Unquote")]
        [switch]$Unquote,

        [Parameter(ParameterSetName = "Unjson")]
        [switch]$UnJson,

        [string]$DefaultHeader = "GLOBAL",

        [string[]]$Comment = "#"
    )

    $Content = $(if ($MyInvocation.ExpectingInput) {$input} else {$InputObject}) | Out-String

    if ($Unquote) {
        $ValueMapper = {$_ -replace "^(['`"``])(.*)(\1)$", '$2'}
    } elseif ($UnJson) {
        $ValueMapper = {$_ | ConvertFrom-Json -AsHashtable:$AsHashtable}
    }


    if ($Comment) {
        $CommentPatterns = $Comment | ForEach-Object {
            if ($_ -match $_) {$_} else {[regex]::Escape($_)}
        }

        $CommentPattern = if ($CommentPatterns.Count -gt 1) {
            "($($CommentPatterns -join '|')).*"
        } else {
            "$CommentPatterns.*"
        }

        $Content = $Content -replace $CommentPattern
    }

    $Content = $Content.TrimStart() -replace '\n\s+(?=\r?\n)'

    $Output = [ordered]@{}

    $Chunks = $Content -split '(?<=\n)(?=\[.*\])'
    foreach ($Chunk in $Chunks) {
        $Header, $Body = $Chunk -split '(?<=^\s*\[.*\])[\s\r\n$]', 2
        if ($Header -match '^\[(?<Header>.*)\]$') {
            $Header = $Matches.Header
        } else {
            $Body = $Header
            $Header = $DefaultHeader
            Write-Warning "Values outside a header have been placed in '$DefaultHeader'"
        }

        $Section = [ordered]@{}
        $Kvps = $Body -split '(?<=\r?\n)(?=\s*\S+\s*=\s*)' | ForEach-Object Trim | Where-Object Length
        foreach ($Kvp in $Kvps) {

            $Key, $Value = $Kvp -split '\s*=\s*', 2

            if ($null -eq $Value) {
                Write-Warning "Key '$Header.$Key' is specified multiple times."
            } else {
                $Value = $Value.Trim()
            }

            if ($ValueMapper) {
                $Value = $Value | ForEach-Object $ValueMapper
            }

            if ($Section.Contains($Key)) {
                Write-Warning "Key '$Header.$Key' is specified multiple times."
            }
            $Section[$Key] = $Value
        }

        $Output[$Header] = if ($AsHashtable) {$Section} else {[pscustomobject]$Section}
    }

    if ($AsHashtable) {$Output} else {[pscustomobject]$Output}
}

function Find-UsbDevice {
    [CmdletBinding(DefaultParameterSetName = "All")]
    param (
        [Parameter(ParameterSetName = "ByFriendlyName", Position = 0)]
        [SupportsWildcards()]
        $Name,

        [Parameter(ParameterSetName = "ByDevice")]
        [SupportsWildcards()]
        $Device,

        [switch]$Raw,

        [switch]$IncludeBus
    )

    if ([Environment]::OSVersion.Platform -notin "Unix", "MaxOSX") {
        throw [NotImplementedException]::new("Not supported on $([Environment]::OSVersion.Platform)")
    }

    if (-not (Get-Command udevadm -ErrorAction Ignore)) {
        throw [Management.Automation.CommandNotFoundException]::new("udevadm not found.")
    }

    $NameProperties = "ID_SERIAL", "ID_USB_SERIAL", "ID_MODEL_FROM_DATABASE", "ID_VENDOR_FROM_DATABASE", "NAME"

    $SysDevPaths = sh -c 'find /sys/bus/usb/devices/usb*/ -name dev'
    foreach ($SysDevPath in $SysDevPaths) {
        $SysPath = Split-Path $SysDevPath
        $DevName = udevadm info -q name -p $SysPath

        if ($Device -and "/dev/$DevName" -notlike $Device) {continue}
        if (-not $IncludeBus -and $DevName.StartsWith("bus/")) {continue}

        $DevProps = udevadm info -q all -p $SysPath

        $Symlinks = @()
        $Properties = [ordered]@{SYSPATH = $SysPath}
        $DevProps | ForEach-Object {
            $Section, $Value = $_ -split ': ', 2
            switch ($Section) {
                "N" {$Key = "NAME"; break}
                "S" {$Symlinks += $Value; return}
                "E" {
                    if ($Symlinks) {
                        $Properties.SYMLINK = [string[]]$Symlinks
                        $Symlinks = $null
                    }
                    $Key, $Value = $Value -split "=", 2
                    break
                }
                default {return}
            }

            if ($Key -eq "DEVLINKS") {
                $Value = $Value -split ' '
            } elseif (-not $Raw -and $Value -match '\\') {
                $Value = printf $Value
            }

            $Properties[$Key] = $Value
        }

        if ($Name -or -not $Raw) {
            $Names = $NameProperties | ForEach-Object {$Properties[$_]} | Where-Object Length
            if ($Name -and -not ($Names -like $Name)) {continue}
        }

        if ($Raw) {
            [pscustomobject]$Properties
        } else {
            [pscustomobject]@{
                FriendlyName = $Names | Select-Object -First 1
                Device = $Properties.DEVNAME
                Properties = [pscustomobject]$Properties
            }
        }
    }
}

function ConvertTo-UrlEncoding {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [string]$InputObject
    )

    process {
        [System.Web.HttpUtility]::UrlEncode($InputObject)
    }
}

function ConvertFrom-UrlEncoding {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [string]$InputObject
    )

    process {
        [System.Web.HttpUtility]::UrlDecode($InputObject)
    }
}

function ConvertTo-TitleCase {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [string]$InputObject
    )

    begin {
        $Culture = Get-Culture
    }

    process {
        $Culture.TextInfo.ToTitleCase($InputObject)
    }
}

function Remove-Quote {
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [string]$Quoted,

        [char[]]$QuoteMarks = "`"'``"
    )

    begin {
        $QuotePattern = $QuoteMarks -join '|'
        $Pattern = "^(?<quote>$QuotePattern)(.*)(\k<quote>)"
    }

    process {
        $Quoted -replace $Pattern, '$1'
    }
}
Set-Alias unquote Remove-Quote

function Repair-Initramfs {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
    param (
        [switch]$All
    )

    $AddVersion = {
        $_ | Add-Member -PassThru -NotePropertyMembers @{
            Version = $_.Name -replace "^.*?-"
        }
    }

    $kernels = gci /boot/vmlinuz-* | % $AddVersion | sort Version
    $inits = gci /boot/initramfs-* | % $AddVersion | sort Version

    $Versions = Compare-Object $kernels $inits -Property Version | ? SideIndicator -eq "<=" | % Version
    if (-not $Versions) {
        Write-Verbose -Verbose "All kernels have a matching initramfs."
        return
    }

    if (-not $All) {
        $Versions = $Versions | Sort-Object | Select-Object -Last 1
    }

    $Versions | % {
        $Version = $_
        if ($PSCmdlet.ShouldProcess($_, "Regenerate initramfs")) {
            sudo dracut --verbose --kver=$Version
            if (!$?) {
                throw
            }
        }
    }
}
