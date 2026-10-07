
if (-not $Global:PSDefaultParameterValues) {$Global:PSDefaultParameterValues = @{}}

$OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = [Text.Utf8Encoding]::new($false)  # no bom
$Global:PSDefaultParameterValues['*:Encoding'] = $Global:PSDefaultParameterValues['*:InputEncoding'] = $Global:PSDefaultParameterValues['*:OutputEncoding'] = $OutputEncoding

$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'

$env:PYTHONSTARTUP = Resolve-Path ~/.pyrc -ErrorAction Ignore

if ($PSVersionTable.PSEdition -ne 'Core')
{
    Set-Variable IsWindows -Value $true -Option Constant -Scope Global
    Set-Variable IsLinux -Value $false -Option Constant -Scope Global
    Set-Variable IsMacOS -Value $false -Option Constant -Scope Global
    Set-Variable IsCoreCLR -Value $false -Option Constant -Scope Global
}

if ($IsLinux -or $IsMacOS)
{
    $NixProfiles = '/etc/profile', '~/.profile', '~/.bash_profile', '~/.bashrc', '~/.bash_login', '~/.bash_logout', '~/.zshrc', '~/.zprofile', '~/.zlogin', '~/.zlogout', '~/.zshenv'
    $NixProfiles += gci '~/.*rc.d' -Directory | gci -File
    [array]::Reverse($NixProfiles)  # user overrides system
    $NixPathLines = Get-Content $NixProfiles -ErrorAction Ignore | Select-String -Pattern '^\s*PATH='
    $Expressions = @($NixPathLines) -replace '.*\bPATH=' -replace "^(?<quote>['`"])(.*)(\k<quote>)$", '$1' -split ':' |
        ? {$_ -ne '$PATH'} | Write-Output | Select-Object -Unique
    $PATH = $Expressions | ForEach-Object {$ExecutionContext.InvokeCommand.ExpandString($_)}
    $PATH += $env:PATH -split ':'
    $PATH = $PATH | Select-Object -Unique
    $env:PATH = @($PATH) -ne '' -join ':'
    Remove-Variable PATH, NixProfiles, NixPathLines, Expressions
}

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

if ($null -eq $Global:IsVSCode)
{
    if ((-not $IsWindows) -and ($env:TERM -ne 'xterm-256color'))  # May not always be this value in Code, but it's definitely not in kitty
    {
        $Global:IsVSCode = $false
    }
    elseif ($env:TERM_PROGRAM)
    {
        $Global:IsVSCode = $env:TERM_PROGRAM -eq 'vscode'
    }
    else
    {
        $Process = Get-Process -Id $PID
        do
        {
            $Global:IsVSCode = $Process.ProcessName -match '^node|(Code( - Insiders)?)|winpty-agent$'
            $Process = $Process.Parent
        }
        while ($Process -and -not $Global:IsVSCode)
    }
}

$env:GITROOT = if (Test-Path /gitroot) {"/gitroot"} elseif (Test-Path ~/gitroot) {"~/gitroot"}

if ($env:GITROOT -and -not $IsVSCode)
{
    Set-Location $env:GITROOT
}

if (Get-Command starship -ErrorAction Ignore)
{
    # brew install starship / choco install starship / winget install Starship.Starship
    $env:STARSHIP_CONFIG = $PSScriptRoot | Split-Path | Join-Path -ChildPath starship.toml
    # starship init powershell --print-full-init | Out-String | Invoke-Expression

    # shaves off ~30ms
    $StarshipInitScript = Join-Path $env:XDG_CONFIG_HOME starship.init.ps1
    if ((gi $StarshipInitScript -ea Ignore).LastWriteTime -lt ([datetime]::Now.AddDays(-7))) {
        starship init powershell --print-full-init > $StarshipInitScript
    }
    . $StarshipInitScript
}

if (Get-Command carapace -ErrorAction Ignore) {
    $env:CARAPACE_NOSPACE = "*"
    $env:CARAPACE_MATCH = 1
    # $env:CARAPACE_BRIDGES = 'zsh,fish,bash,inshellisense' # optional
    # carapace _carapace | Out-String | Invoke-Expression

    # shaves off ~100ms
    $env:CARAPACE_BRIDGES = 'bash'
    $CarapaceInitScript = Join-Path $env:XDG_CONFIG_HOME carapace.init.ps1
    if ((gi $CarapaceInitScript -ea Ignore).LastWriteTime -lt ([datetime]::Now.AddDays(-7))) {
        carapace _carapace > $CarapaceInitScript
    }
    . $CarapaceInitScript
}

. "{{ .chezmoi.sourceDir }}/PSHelpers/Console.ps1"

Update-FormatData -PrependPath "{{ .chezmoi.sourceDir }}/PSHelpers/FileSystem.Format.ps1xml"

if ($IsVSCode)
{
    Activate-PyEnv -ErrorAction Ignore
    Set-Alias activate Activate-PyEnv
}
