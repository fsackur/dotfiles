enum JournalPriority {
    emerg = 0
    alert = 1
    crit = 2
    err = 3
    warning = 4
    notice = 5
    info = 6
    debug = 7
}

function Read-Journal {
    [OutputType("JournalBoot", ParameterSetName = "Structured")]
    [OutputType([string], ParameterSetName = "Raw")]
    [CmdletBinding(DefaultParameterSetName = "Structured")]
    param
    (
        [Parameter(Position = 0)]
        [SupportsWildcards()]
        [string[]]$Id,

        [string[]]$Unit,

        [string[]]$SyslogId,

        [string[]]$ExcludeSyslogId,

        [string[]]$Facility,

        [Alias("Grep")]
        [regex]$Pattern,

        [Alias("Level")]
        [JournalPriority]$Priority,

        [switch]$CaseSensitive,

        [ValidateRange(1, [int]::MaxValue)]
        [Alias("Lines")]
        [int]$Count,

        [switch]$Follow,

        [switch]$User,

        [switch]$Dmesg,

        [string]$Boot,

        [string]$Since,

        [string]$Until,

        [Parameter(ParameterSetName = "Raw")]
        [ValidateScript({$_})]
        [switch]$Raw,

        [Parameter(ParameterSetName = "Raw")]
        [ValidateSet("short", "short-precise", "short-iso", "short-iso-precise", "short-full", "short-monotonic", "short-unix", "verbose", "export", "json", "json-pretty", "json-sse", "json-seq", "cat", "with-unit")]
        [string]$Format,

        [ValidateSet("CODE_LINE", "_COMM", "INITRD_USEC", "_AUDIT_ID", "DISK_AVAILABLE", "OPERATION", "UNIT", "_AUDIT_FIELD_SUCCESS", "PRIORITY", "SYSLOG_FACILITY", "_UID", "_AUDIT_TYPE", "_AUDIT_FIELD_SCONTEXT", "TID", "JOB_TYPE", "_AUDIT_FIELD_TABLE", "LEADER", "AUDIT_FIELD_DEFAULT_CONTEXT", "NM_LOG_DOMAINS", "DISK_KEEP_FREE", "JOB_RESULT", "_TTY", "REF", "INVOCATION_ID", "_SYSTEMD_USER_UNIT", "AUDIT_FIELD_NEW_LEVEL", "AUDIT_FIELD_UNIT", "_AUDIT_FIELD_A1", "SEAT_ID", "AUDIT_FIELD_HOSTNAME", "JOURNAL_NAME", "_UDEV_DEVNODE", "_AUDIT_FIELD_TCONTEXT", "CODE_FILE", "_SYSTEMD_SLICE", "AVAILABLE_PRETTY", "_FSUID", "_AUDIT_FIELD_ENTRIES", "_SOURCE_MONOTONIC_TIMESTAMP", "SESSION_ID", "_EXE", "AVAILABLE", "_AUDIT_FIELD_INO", "_AUDIT_FIELD_AUDIT_ENABLED", "_AUDIT_FIELD_PERMISSIVE", "AUDIT_FIELD_ACCT", "CURRENT_USE", "_AUDIT_FIELD_FAMILY", "_SYSTEMD_USER_SLICE", "CURRENT_USE_PRETTY", "_AUDIT_SESSION", "INSTALLATION", "_STREAM_ID", "MESSAGE_ID", "DBUS_BROKER_LOG_DROPPED", "_MACHINE_ID", "AUDIT_FIELD_OLD_LEVEL", "USER_UNIT", "_AUDIT_FIELD_SGID", "THREAD_ID", "_AUDIT_FIELD_TCLASS", "_AUDIT_FIELD_SYSCALL", "_CMDLINE", "DISK_AVAILABLE_PRETTY", "_RUNTIME_SCOPE", "LIMIT_PRETTY", "SYSLOG_PID", "_AUDIT_FIELD_AUDIT_PID", "_AUDIT_FIELD_SUID", "_FSGID", "CONFIG_FILE", "_AUDIT_TYPE_NAME", "GLIB_DOMAIN", "_SYSTEMD_OWNER_UID", "CODE_FUNC", "_AUDIT_FIELD_ARCH", "_SYSTEMD_SESSION", "USER_ID", "_GID", "KERNEL_USEC", "_AUDIT_FIELD_NAME", "AUDIT_FIELD_COMM", "REALMD_OPERATION", "REMOTE", "_PID", "LIMIT", "ERRNO", "_AUDIT_FIELD_KEY", "OBJECT_PID", "_EGID", "_KERNEL_DEVICE", "_UDEV_SYSNAME", "OLD_COMMIT", "_SYSTEMD_UNIT", "_AUDIT_FIELD_PROG_ID", "MEMORY_SWAP_PEAK", "COMMIT", "FLATPAK_VERSION", "INTERFACE", "_AUDIT_LOGINUID", "MAX_USE", "_KERNEL_SUBSYSTEM", "_AUDIT_FIELD_RES", "_PPID", "_CAP_EFFECTIVE", "_SELINUX_CONTEXT", "AUDIT_FIELD_ADDR", "TIMESTAMP_BOOTTIME", "JOB_ID", "AUDIT_FIELD_TERMINAL", "_AUDIT_FIELD_OLD", "_AUDIT_FIELD_A2", "USER_INVOCATION_ID", "_TRANSPORT", "_AUDIT_FIELD_OP", "AUDIT_FIELD_EXE", "JOURNAL_PATH", "TAINT", "TIMESTAMP_MONOTONIC", "MESSAGE", "_SYSTEMD_INVOCATION_ID", "_AUDIT_FIELD_A3", "CONFIG_LINE", "_AUDIT_FIELD_EXIT", "_AUDIT_FIELD_DEV", "_EUID", "MEMORY_PEAK", "NM_DEVICE", "AUDIT_FIELD_GRANTORS", "SYSLOG_IDENTIFIER", "_AUDIT_FIELD_ITEMS", "_SOURCE_REALTIME_TIMESTAMP", "SYSLOG_TIMESTAMP", "_HOSTNAME", "AUDIT_FIELD_RES", "AUDIT_FIELD_OP", "DISK_KEEP_FREE_PRETTY", "_BOOT_ID", "_AUDIT_FIELD_A0", "SYSLOG_RAW", "GLIB_OLD_LOG_API", "USERSPACE_USEC", "_SYSTEMD_CGROUP", "CPU_USAGE_NSEC", "URL", "MAX_USE_PRETTY", "NM_LOG_LEVEL", "DBUS_BROKER_METRICS_DISPATCH_MIN", "OBJECT_SYSTEMD_SLICE", "OBJECT_SYSTEMD_USER_UNIT", "TOPIC", "SRC", "DBUS_BROKER_METRICS_DISPATCH_STDDEV", "DBUS_BROKER_SENDER_SECURITY_LABEL", "CHECKSUM_ALGORITHM", "SETYPE", "DEST", "DBUS_BROKER_LAUNCH_SERVICE_UNIT", "OBJECT_AUDIT_SESSION", "DBUS_BROKER_MESSAGE_MEMBER", "AUDIT_FIELD_GPG_RES", "SEUSER", "DBUS_BROKER_SENDER_WELL_KNOWN_NAME_0", "GATHER_TIMEOUT", "SHUTDOWN", "AUDIT_FIELD_ROOT_DIR", "PATH", "DBUS_BROKER_METRICS_DISPATCH_COUNT", "OBJECT_SYSTEMD_USER_SLICE", "DBUS_BROKER_MESSAGE_INTERFACE", "AUDIT_FIELD_KEY_ENFORCE", "SSSD_PRG_NAME", "DBUS_BROKER_POLICY_TYPE", "NM_CONNECTION", "RECURSE", "GATHER_SUBSET", "DBUS_BROKER_LAUNCH_SERVICE_ID", "AUDIT_FIELD_CIPHER", "SCOPE", "DBUS_BROKER_MESSAGE_SERIAL", "OBJECT_SELINUX_CONTEXT", "GET_CHECKSUM", "AUDIT_FIELD_SW_TYPE", "DBUS_BROKER_TRANSMIT_ACTION", "DBUS_BROKER_LAUNCH_SERVICE_NAME", "STATE", "FILTER", "OBJECT_UID", "DBUS_BROKER_LAUNCH_BUS_ERROR_MESSAGE", "GET_MIME", "DBUS_BROKER_LAUNCH_ARG0", "DBUS_BROKER_MESSAGE_TYPE", "DBUS_BROKER_MESSAGE_UNIX_FDS", "DBUS_BROKER_LAUNCH_SERVICE_USER", "MODE", "SSSD_DOMAIN", "ACCESS_TIME", "AUDIT_FIELD_SW", "AUDIT_FIELD_CWD", "DBUS_BROKER_SENDER_UNIQUE_NAME", "AUDIT_FIELD_KIND", "OBJECT_GID", "DBUS_BROKER_MESSAGE_PATH", "OBJECT_AUDIT_LOGINUID", "SEROLE", "DBUS_BROKER_METRICS_DISPATCH_MAX", "MODIFICATION_TIME_FORMAT", "ACTION", "DBUS_BROKER_LAUNCH_SERVICE_UID", "AUDIT_FIELD_KSIZE", "AUDIT_FIELD_MAC", "OPERATOR", "DBUS_BROKER_LAUNCH_SERVICE_PATH", "AUDIT_FIELD_LADDR", "AUDIT_FIELD_FP", "AUDIT_FIELD_PFS", "_LINE_BREAK", "DBUS_BROKER_MESSAGE_SIGNATURE", "FACT_PATH", "DAEMON_REEXEC", "SELEVEL", "DBUS_BROKER_LAUNCH_SERVICE_INSTANCE", "ENABLED", "AUDIT_FIELD_LPORT", "FORCE", "ACCESS_TIME_FORMAT", "OWNER", "DBUS_BROKER_RECEIVER_SECURITY_LABEL", "UNSAFE_WRITES", "DBUS_BROKER_METRICS_DISPATCH_AVG", "AUDIT_FIELD_CMD", "MODIFICATION_TIME", "AUDIT_FIELD_ID", "OBJECT_CMDLINE", "MODULE", "MASKED", "AUDIT_FIELD_SUID", "OBJECT_SYSTEMD_UNIT", "GROUP", "DBUS_BROKER_LAUNCH_BUS_ERROR_NAME", "OBJECT_SYSTEMD_OWNER_UID", "AUDIT_FIELD_DIRECTION", "NO_BLOCK", "GET_ATTRIBUTES", "DAEMON_RELOAD", "AUDIT_FIELD_SPID", "ATTRIBUTES", "OBJECT_SYSTEMD_INVOCATION_ID", "OBJECT_EXE", "FOLLOW", "DBUS_BROKER_RECEIVER_UNIQUE_NAME", "_AUDIT_FIELD_CAPABILITY", "AUDIT_FIELD_RPORT", "OBJECT_SYSTEMD_CGROUP", "DBUS_BROKER_MESSAGE_DESTINATION", "OBJECT_COMM", "OBJECT_CAP_EFFECTIVE", "NAME", "BUGFIX", "BACKUP", "THROTTLE", "STRIP_EMPTY_ENDS", "INSTALLROOT", "IP_RESOLVE", "ENABLE_PLUGIN", "CREATES", "DISABLE_PLUGIN", "SKIP_BROKEN", "CACHEONLY", "PROTECT", "ALLOW_DOWNGRADE", "GPGCHECK", "FAILOVERMETHOD", "EXECUTABLE", "UI_REPOID_VARS", "DIRECTORY_MODE", "ALLOWERASING", "ENABLEGROUPS", "INCLUDE", "PASSWORD", "AUTOREMOVE", "VALIDATE", "FILE", "PROXY", "S3_ENABLED", "AUTO_INSTALL_MODULE_DEPS", "HTTP_CACHING", "INSERTBEFORE", "INSTALL_WEAK_DEPS", "ASYNC", "REMOTE_SRC", "FINGERPRINT", "INSTALL_REPOQUERY", "NOBEST", "CREATE", "DISABLEREPO", "SECURITY", "RETRIES", "KEEPALIVE", "VALIDATE_CERTS", "INSERTAFTER", "GPGKEY", "CHDIR", "CHECKSUM", "REMOVES", "SKIP_IF_UNAVAILABLE", "SSLCLIENTCERT", "TIMEOUT", "CONTENT", "METALINK", "KEY", "REPO_GPGCHECK", "STDIN_ADD_NEWLINE", "PROXY_PASSWORD", "BASEURL", "SSLVERIFY", "LINE", "DELTARPM_METADATA_PERCENTAGE", "DESCRIPTION", "GPGCAKEY", "SSL_CHECK_CERT_PERMISSIONS", "LOCAL_FOLLOW", "MIRRORLIST", "ARGV", "BANDWIDTH", "MIRRORLIST_EXPIRE", "SSLCACERT", "PROXY_USERNAME", "REPOSDIR", "ENABLEREPO", "LIST", "DOWNLOAD_ONLY", "EXPAND_ARGUMENT_VARS", "MODULE_HOTFIXES", "LOCK_TIMEOUT", "COST", "DELTARPM_PERCENTAGE", "USERNAME", "METADATA_EXPIRE_FILTER", "SSLCLIENTKEY", "REGEXP", "DISABLE_GPG_CHECK", "DOWNLOAD_DIR", "UPDATE_ONLY", "INCLUDEPKGS", "DISABLE_EXCLUDES", "FIRSTMATCH", "CONF_FILE", "UPDATE_CACHE", "SEARCH_STRING", "EXCLUDE", "BACKREFS", "RELEASEVER", "KEEPCACHE", "STDIN", "METADATA_EXPIRE", "SSH_KEY_COMMENT", "PASSWORD_LOCK", "UPDATE_PASSWORD", "PROFILE", "GROUPS", "AUTHORIZATION", "SKELETON", "EXPIRES", "HIDDEN", "PASSWORD_EXPIRE_MIN", "SSH_KEY_FILE", "COMMENT", "AUDIT_FIELD_GRP", "MOVE_HOME", "CREATE_HOME", "PASSWORD_EXPIRE_WARN", "SSH_KEY_BITS", "UID", "HOME", "PASSWORD_EXPIRE_MAX", "GENERATE_SSH_KEY", "SSH_KEY_PASSPHRASE", "UMASK", "APPEND", "ROLE", "REMOVE", "NON_UNIQUE", "SHELL", "LOCAL", "SSH_KEY_TYPE", "SYSTEM", "LOGIN_CLASS", "CONTAINS", "AGE_STAMP", "READ_WHOLE_FILE", "DEPTH", "FILE_TYPE", "PATHS", "PATTERNS", "USE_REGEX", "EXACT_MODE", "AGE", "EXCLUDES", "SIZE", "IO_BUFFER_SIZE", "DECOMPRESS", "CLIENT_CERT", "CIPHERS", "METHOD", "HEADERS", "OSTREE_REMOTE", "COPY", "URL_PASSWORD", "HTTP_AGENT", "URL_USERNAME", "USE_PROXY", "USE_GSSAPI", "DECRYPT", "UNREDIRECTED_HEADERS", "EXTRA_OPTS", "OSTREE_GPG", "KEEP_NEWER", "USE_NETRC", "LIST_FILES", "NO_DEPENDENCIES", "CLIENT_KEY", "TMP_DEST", "FORCE_BASIC_AUTH", "OSTREE_SIGN", "OSTREE_SECONDS", "OSTREE_XFER_SIZE", "AUDIT_FIELD_LSM", "XMLSTRING", "INPUT_TYPE", "NAMESPACES", "AUDIT_FIELD_SEQNO", "ATTRIBUTE", "AUDIT_FIELD_SAUID", "PRINT_MATCH", "VALUE", "STRIP_CDATA_TAGS", "ADD_CHILDREN", "_AUDIT_FIELD_LSM", "XPATH", "PRETTY_PRINT", "COUNT", "SET_CHILDREN", "AUDIT_FIELD_TGLOB", "_AUDIT_FIELD_LIST", "AUDIT_FIELD_FTYPE", "AUDIT_FIELD_RESRC", "AUDIT_FIELD_TCONTEXT", "PROBLEM_COUNT", "PROBLEM_BINARY", "PROBLEM_UUID", "PROBLEM_CRASH_FUNCTION", "_UDEV_DEVLINK", "PROBLEM_DIR", "UNIT_RESULT", "PROBLEM_PID", "DEVICE", "PROBLEM_REASON", "_AUDIT_FIELD_SADDR", "PROBLEM_REPORT", "_AUDIT_FIELD_SIG", "SLEEP", "EXIT_CODE", "EXIT_STATUS", "COMMAND", "VIRTUALENV", "_AUDIT_FIELD_OLD_PROM", "VIRTUALENV_COMMAND", "IO_METRIC_WRITE_OPERATIONS", "VIRTUALENV_SITE_PACKAGES", "IO_METRIC_WRITE_BYTES", "_AUDIT_FIELD_PROM", "REQUIREMENTS", "VERSION", "EXTRA_ARGS", "EDITABLE", "IO_METRIC_READ_OPERATIONS", "IO_METRIC_READ_BYTES", "VIRTUALENV_PYTHON", "DNS4", "FORWARDDELAY", "HELLOTIME", "RUNNER_FAST_RATE", "MIIMON", "STP", "DNS6_SEARCH", "AUDIT_FIELD_ACL", "HAIRPIN", "ROUTE_METRIC4", "DOWNDELAY", "AUDIT_FIELD_RDEV", "DNS6_IGNORE_AUTO", "INGRESS", "AUDIT_FIELD_NET", "IFNAME", "GSM", "AUDIT_FIELD_OLD_DISK", "WIFI", "ZONE", "SLAVEPRIORITY", "NEVER_DEFAULT4", "VXLAN_ID", "GW6", "XMIT_HASH_POLICY", "LIBVIRT_DOMAIN", "ARP_IP_TARGET", "LIBVIRT_SOURCE", "GW4", "LIBVIRT_CODE", "AUDIT_FIELD_PATH", "VXLAN_LOCAL", "AUDIT_FIELD_DEVICE", "AUDIT_FIELD_OLD_MEM", "CONN_NAME", "WIREGUARD", "ROUTES6", "ROUTE_METRIC6", "AUDIT_FIELD_CLASS", "UPDELAY", "IP_TUNNEL_REMOTE", "AUDIT_FIELD_OLD_NET", "AUDIT_FIELD_OLD_VCPU", "AUDIT_FIELD_NEW_VCPU", "ROUTES4", "PRIMARY", "ADDR_GEN_MODE6", "SSID", "AUDIT_FIELD_OLD_CHARDEV", "AUDIT_FIELD_NEW_DISK", "PATH_COST", "AUDIT_FIELD_MODEL", "VXLAN_REMOTE", "AUDIT_FIELD_VM", "SLAVE_TYPE", "MAXAGE", "WIFI_SEC", "FLAGS", "MAY_FAIL4", "AGEINGTIME", "AUDIT_FIELD_IMG_CTX", "AUDIT_FIELD_UUID", "DNS6", "MTU", "MASTER", "ARP_INTERVAL", "AUDIT_FIELD_VM_CTX", "METHOD4", "DNS4_OPTIONS", "GW6_IGNORE_AUTO", "AUDIT_FIELD_BUS", "EGRESS", "AUDIT_FIELD_VIRT", "ROUTES4_EXTENDED", "AUDIT_FIELD_REASON", "ROUTES6_EXTENDED", "DNS4_IGNORE_AUTO", "AUDIT_FIELD_VM_PID", "VPN", "TYPE", "DNS4_SEARCH", "TRANSPORT_MODE", "IP_TUNNEL_LOCAL", "AUDIT_FIELD_NEW_NET", "AUDIT_FIELD_MAJ", "IP_TUNNEL_DEV", "AUDIT_FIELD_NEW_MEM", "ROUTING_RULES4", "IP_TUNNEL_INPUT_KEY", "IP6", "DHCP_CLIENT_ID", "IP_PRIVACY6", "DNS6_OPTIONS", "IP4", "IP_TUNNEL_OUTPUT_KEY", "MAC", "RUNNER_HWADDR_POLICY", "GW4_IGNORE_AUTO", "VLANDEV", "MACVLAN", "RUNNER", "AUDIT_FIELD_CATEGORY", "AUDIT_FIELD_NEW_CHARDEV", "VLANID", "METHOD6", "IGNORE_UNSUPPORTED_SUBOPTIONS", "AUTOCONNECT", "AUDIT_FIELD_CGROUP", "N_RESTARTS", "COREDUMP_TIMESTAMP", "COREDUMP_PACKAGE_NAME", "COREDUMP_GID", "COREDUMP_PROC_STATUS", "COREDUMP_FILENAME", "PODMAN_EVENT", "PODMAN_TIME", "COREDUMP_CGROUP", "COREDUMP_PROC_AUXV", "COREDUMP_PROC_LIMITS", "COREDUMP_ENVIRON", "COREDUMP_OPEN_FDS", "COREDUMP_RLIMIT", "COREDUMP_UID", "COREDUMP_USER_UNIT", "COREDUMP_PROC_MOUNTINFO", "COREDUMP_PROC_MAPS", "COREDUMP_PACKAGE_VERSION", "COREDUMP_PACKAGE_JSON", "PODMAN_TYPE", "COREDUMP_UNIT", "COREDUMP_CMDLINE", "COREDUMP_PROC_CGROUP", "COREDUMP_SLICE", "COREDUMP_ROOT", "COREDUMP_SIGNAL_NAME", "COREDUMP_PID", "COREDUMP_HOSTNAME", "COREDUMP_SIGNAL", "COREDUMP_COMM", "COREDUMP_CWD", "COREDUMP_EXE", "COREDUMP_OWNER_UID", "SRC_RANGE", "SET_DSCP_MARK_CLASS", "TCP_FLAGS", "LIMIT_BURST", "FLUSH", "DST_RANGE", "IP_VERSION", "RULE_NUM", "SET_COUNTERS", "CHAIN_MANAGEMENT", "TO_SOURCE", "MATCH_SET", "POLICY", "MATCH_SET_FLAGS", "DESTINATION_PORTS", "MATCH", "DESTINATION", "SOURCE_PORT", "WAIT", "GATEWAY", "IN_INTERFACE", "SET_DSCP_MARK", "LOG_LEVEL", "REJECT_WITH", "DESTINATION_PORT", "OUT_INTERFACE", "TABLE", "SYN", "ICMP_TYPE", "TO_DESTINATION", "UID_OWNER", "FRAGMENT", "TO_PORTS", "LOG_PREFIX", "GOTO", "CHAIN", "CTSTATE", "PROTOCOL", "SOURCE", "GID_OWNER", "JUMP", "NUMERIC", "DBUS_BROKER_LAUNCH_ARG1", "BOLT_LOG_CONTEXT", "BOLT_VERSION", "BOLT_TOPIC", "AUDIT_FIELD_NEW_FS", "_AUDIT_FIELD_PATH", "AUDIT_FIELD_OLD_FS")]
        [string[]]$Fields,

        [switch]$Sudo
    )

    $StructuredOutputArg = "--output=json"
    $_args = @()

    if ($Id) {
        $All = Get-JournalId
        $Filters = $Id
            | % {
                $_Id = $_
                $All | ? Value -ilike $_Id
            } |
            Select-Object -Unique

        $Filters |
            Select-Object -SkipLast 1 |
            % {
                $_args += $_.Field, $_.Value -join "="
                $_args += "+"
            }

        $Filters |
            Select-Object -Last 1 |
            % {
                $_args += $_.Field, $_.Value -join "="
            }
    }

    if ($Unit) {
        $param = if ($User) {"user-unit"} else {"unit"}
        $Unit | % {
            $_args += "--$param=$_"
        }
    }

    if ($SyslogId) {
        $SyslogId | % {
            $_args += "--identifier=$_"
        }
    }

    if ($ExcludeSyslogId) {
        $ExcludeSyslogId | % {
            $_args += "--exclude-identifier=$_"
        }
    }

    if ($Facility) {
        $_args += "--facility=$($Facility -join ',')"
    }

    if ($Pattern) {
        $_args += "--grep=$Pattern"
        if (-not $CaseSensitive) {
            $_args += "--case-sensitive=false"
        }
    }

    if ($null -ne $Priority) {
        $_args += "--priority=$Priority"
    }

    if ($Count) {$_args += "--lines=$Count"}
    if ($Follow) {$_args += "--follow"}
    if ($User) {$_args += "--user"}
    if ($Dmesg) {$_args += "--dmesg"}
    if ($Boot) {$_args += "--boot=$Boot"}

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

    if ($PSCmdlet.ParameterSetName -eq "Raw") {
        if ($Format) {$_args += "--output=$Format"}
        if ($Fields) {$_args += "--output-fields=$($Fields -join ',')"}
    } else {
        $_args += $StructuredOutputArg
        if ($Fields) {
            $Required = "__REALTIME_TIMESTAMP", "_HOSTNAME", "SYSLOG_IDENTIFIER", "_PID", "MESSAGE"
            $Fields = $Required, $Fields | Write-Output | Select-Object -Unique
            $_args += "--output-fields=$($Fields -join ',')"
        }
    }

    $Reader = {
        if ($Sudo)
        {
            sudo journalctl @_args
        }
        else
        {
            journalctl @_args
        }
    }

    if ($PSCmdlet.ParameterSetName -eq "Raw") {
        Write-Verbose "journalctl $_args"
        & $Reader
    } else {
        Write-Verbose "journalctl $(@($_args) -ne $StructuredOutputArg)"
        & $Reader | % -OutBuffer 0 {
            $Entry = ConvertFrom-Json $_
            $Entry.PSTypeNames.Insert(0, "JournalEntry")
            $Entry
        }
    }
}

function Get-JournalBoot {
    [OutputType("JournalBoot")]
    [CmdletBinding()]
    param ()

    journalctl --list-boots -o json | ConvertFrom-Json | % {$_.PSTypeNames.Insert(0, "JournalBoot"); $_}
}

$script:JournalFields = $null
function script:Get-JournalFieldName {
    [OutputType([string])]
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [SupportsWildcards()]
        [string]$Name
    )

    if (-not $Script:JournalFields) {
        $Script:JournalFields = journalctl --fields | Sort-Object {$_ -replace "^_+"}
    }

    if ($Name) {
        $Script:JournalFields -ilike $Name
    } else {
        $Script:JournalFields
    }
}

function Get-JournalField {
    [OutputType([string])]
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [SupportsWildcards()]
        [string]$Name
    )

    $Fields = Get-JournalFieldName @PSBoundParameters
    $Fields | % {
        $Field = $_
        journalctl -F $Field |
            % {Add-Member -PassThru -InputObject $_ -NotePropertyMembers @{Field = $Field; Value = $_}} |
            % {$_.PSTypeNames.Insert(0, "JournalValue"); $_} |
            Sort-Object
    }
}

function Get-JournalUnit {
    [OutputType("JournalUnit")]
    [CmdletBinding()]
    param (
        [ValidateSet("Unit", "Slice", "UserUnit", "UserSlice")]
        [string[]]$Type = ("Unit", "Slice", "UserUnit", "UserSlice"),

        [Parameter(Position = 0)]
        [SupportsWildcards()]
        [string]$Name
    )

    $NameFilter = if ($Name) {
        {$_ -like $Name -or $_ -like "$Name.*"}
    } else {
        {$true}
    }

    $FieldMap = @{
        "Unit"      = "_SYSTEMD_UNIT"
        "Slice"     = "_SYSTEMD_SLICE"
        "UserUnit"  = "_SYSTEMD_USER_UNIT"
        "UserSlice" = "_SYSTEMD_USER_SLICE"
    }

    $ValidValues = $MyInvocation.MyCommand.Parameters.Type.Attributes | ? {$_ -is [ValidateSet]} | % ValidValues

    $Types = $Type | % {$ValidValues -like $_} | Sort-Object {$ValidValues.IndexOf($_)} -Unique
    $Types | % {
        $UnitType = $_
        Get-JournalField $FieldMap[$UnitType] |
            ? $NameFilter |
            % {Add-Member -PassThru -InputObject $_ -NotePropertyMembers @{UnitType = $UnitType}} |
            % {$_.PSTypeNames.Insert(0, "JournalUnit"); $_} |
            Sort-Object
    }
}

function script:Get-JournalId {
    $Fields = "SYSLOG_IDENTIFIER", "_SYSTEMD_UNIT", "_SYSTEMD_SLICE", "_SYSTEMD_USER_UNIT", "_SYSTEMD_USER_SLICE"
    $Fields | % {Get-JournalField $_} | Sort-Object
}


Register-ArgumentCompleter -CommandName Get-JournalField -ParameterName Name -ScriptBlock {
    param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    $Names = Get-JournalFieldName
    (@($Names) -like "$wordToComplete*"), (@($Names) -like "*$wordToComplete*") | Write-Output | Select-Object -Unique
}

Register-ArgumentCompleter -CommandName Read-Journal -ParameterName Boot -ScriptBlock {
    param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    $Boots = Get-JournalBoot | Sort-Object Index -Descending
    $Names = "all", $Boots.index, $Boots.boot_id | Write-Output
    (@($Names) -like "$wordToComplete*"), (@($Names) -like "*$wordToComplete*") | Write-Output | Select-Object -Unique
}

Register-ArgumentCompleter -CommandName Read-Journal -ParameterName Id -ScriptBlock {
    param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    $Names = Get-JournalId
    (@($Names) -like "$wordToComplete*"), (@($Names) -like "*$wordToComplete*") | Write-Output | Select-Object -Unique
}

Register-ArgumentCompleter -CommandName Read-Journal -ParameterName Unit -ScriptBlock {
    param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    $UnitType = if ($fakeBoundParameters.User) {"UserUnit", "UserSlice"} else {"Unit", "Slice"}
    $Names = (Get-JournalUnit -Type $UnitType) -replace "\.service$" | Sort-Object
    (@($Names) -like "$wordToComplete*"), (@($Names) -like "*$wordToComplete*") | Write-Output | Select-Object -Unique
}

$SyslogIdCompleter = {
    param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    $Names = Get-JournalField SYSLOG_IDENTIFIER
    $Completions = (@($Names) -like "$wordToComplete*"), (@($Names) -like "*$wordToComplete*") | Write-Output | Select-Object -Unique
    $Completions -replace "^\(.*\)$", "'`$0'"
}
Register-ArgumentCompleter -CommandName Read-Journal -ParameterName SyslogId -ScriptBlock $SyslogIdCompleter
Register-ArgumentCompleter -CommandName Read-Journal -ParameterName ExcludeSyslogId -ScriptBlock $SyslogIdCompleter

Register-ArgumentCompleter -CommandName Read-Journal -ParameterName Facility -ScriptBlock {
    param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    $Names = journalctl --facility=help
    (@($Names) -like "$wordToComplete*"), (@($Names) -like "*$wordToComplete*") | Write-Output | Select-Object -Unique
}
