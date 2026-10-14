
$Script:ScriptRoot = realpath $PSCommandPath | Split-Path
$PSModulePaths = $env:PSModulePath -split [System.IO.Path]::PathSeparator
$PSModulePath = $PSModulePaths | Where-Object {$_.StartsWith($env:HOME)} | Select-Object -Last 1
$PSAllUserModulePath = $PSModulePaths | Where-Object {-not $_.StartsWith($env:HOME)} | Select-Object -First 1

function Update-HelperModule {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, ValueFromPipeline)]
        [ArgumentCompleter({
            param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

            $Files = Get-ChildItem $ScriptRoot -Filter *.ps1 | % BaseName
            (@($Files) -like "$wordToComplete*"), (@($Files) -like "*$wordToComplete*") | Write-Output
        })]
        [string[]]$Name,

        [ValidateSet("Copy", "Link")]
        [string]$Type = "Link",

        [switch]$AllUsers
    )

    if ($MyInvocation.ExpectingInput) {
        $Name = $input
    }

    $ModulePath = if ($AllUsers) {$PSAllUserModulePath} else {$PSModulePath}

    if (-not $Name) {
        $Name = Get-ChildItem $ScriptRoot -Filter *.ps1 | % BaseName
    }

    function deploy {
        [CmdletBinding()]
        param ($Source, $Dest)

        $Dest = if ($Dest) {$Dest} else {$Source}
        $Source = realpath (Join-Path $ScriptRoot $Source)

        $Action = if ($Type -eq "Copy") {
            {
                pushd $ModuleBase > /dev/null
                cp -f $Source $Dest
                popd > /dev/null
            }
        } elseif ((Get-Item $Dest -ea Ignore).LinkTarget -ne $Source) {
            {
                pushd $ModuleBase > /dev/null
                ln -sf $Source $Dest
                popd > /dev/null
            }
        }

        if ($AllUsers) {
            sudo sh -c ($ExecutionContext.InvokeCommand.ExpandString($Action))
        } else {
            & $Action
        }
    }

    Push-Location $ScriptRoot -ea Stop
    try {
        foreach ($_Name in $Name) {
            $_Name = $_Name -replace "\.ps1$"  # belt-and-braces; we're expecting basename anyway
            $SourceScript = [IO.Path]::ChangeExtension($_Name, "ps1")
            $SourcePath = $SourceScript | Resolve-Path -ea Stop
            $ModuleBase = Join-Path $ModulePath $_Name
            $Manifest = @{
                RootModule = [IO.Path]::ChangeExtension($_Name, "psm1")
            }

            if ($AllUsers) {
                sudo mkdir -p $ModuleBase
                sudo chown -R (id -u) $ModuleBase
            } else {
                mkdir -p $ModuleBase
            }

            # Tidy deprecated links
            $Deprecated = Join-Path $ModuleBase "$_Name.ps1"
            if (Test-Path $Deprecated) {del $Deprecated}

            deploy -Source $SourceScript -Dest $Manifest.RootModule

            $TypeFilename = [IO.Path]::ChangeExtension($_Name, "Types.ps1xml")
            if (Test-Path $TypeFilename) {
                deploy -Source $TypeFilename
                $Manifest.TypesToProcess = $TypeFileName
            }

            $FormatFileName = [IO.Path]::ChangeExtension($_Name, "Format.ps1xml")
            if (Test-Path $FormatFileName) {
                deploy -Source $FormatFileName
                $Manifest.FormatsToProcess = $FormatFileName
            }

            $Ast = [Management.Automation.Language.Parser]::ParseFile($SourcePath, [ref]$null, [ref]$null)
            $FunctionAsts = $Ast.FindAll({
                param ($Ast)
                $Ast -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                $Ast.Name -inotlike "private:*" -and
                $Ast.Name -inotlike "script:*" -and
                $Ast.Parent.Parent -isnot [System.Management.Automation.Language.TypeDefinitionAst]  # ignore class methods; apparently, a type definition isn't a nested scriptblock
            }, $false)
            $Manifest.FunctionsToExport = $FunctionAsts.Name

            $AliasAsts = $Ast.FindAll({
                param ($Ast)
                $Ast -is [System.Management.Automation.Language.CommandAst] -and
                $Ast.CommandElements[0].Value -eq "Set-Alias"
            }, $false)
            $Manifest.AliasesToExport = $AliasAsts | % {$_.CommandElements[1].Value}

            $AssignmentAsts = $Ast.FindAll({
                param ($Ast)
                $Ast -is [System.Management.Automation.Language.AssignmentStatementAst]
            }, $false)
            $VariableAsts = $AssignmentAsts.Left.Target
            $Variables = $VariableAsts.VariablePath | ? IsGlobal | % UserPath
            $Manifest.VariablesToExport = $Variables -replace '^.*:'


            $ManifestPath = Join-Path $ModuleBase ([IO.Path]::ChangeExtension($_Name, "psd1"))
            New-ModuleManifest $ManifestPath @Manifest


            if ($AllUsers) {
                sudo chown -R (id -u) $ModuleBase
            }
        }

    } finally {
        Pop-Location
    }
}

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

function Clear-KnownHost
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

function Stop-VSCodeRemote
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
Set-Alias Kill-VSCodeRemote Stop-VSCodeRemote

function Use-PyEnv
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 0)]
        [string]$Path = $(Resolve-Path .conda, .venv -ErrorAction Ignore | Select-Object -First 1)
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
        $Script = Join-Path $Path bin | gci -Filter Activate.ps1  # resolve case-sensitivity
        . $Script
    }
}
Set-Alias Activate-PyEnv Use-PyEnv

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

    (@($TaskNames) -like "$wordToComplete*"), (@($TaskNames) -like "*$wordToComplete*") | Write-Output | Select-Object -Unique
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
