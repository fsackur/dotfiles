
if (-not $Global:PSDefaultParameterValues) {$Global:PSDefaultParameterValues = @{}}

$OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = [Text.Utf8Encoding]::new($false)  # no bom
$Global:PSDefaultParameterValues['*:Encoding'] = $Global:PSDefaultParameterValues['*:InputEncoding'] = $Global:PSDefaultParameterValues['*:OutputEncoding'] = $OutputEncoding

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
    [array]::Reverse($NixProfiles)  # user overrides system
    $NixPathLines = Get-Content $NixProfiles -ErrorAction Ignore | Select-String -Pattern '^\s+PATH='
    $Expressions = @($NixPathLines) -replace '.*PATH\s*=\s*' -replace "^(?<quote>['`"])(.*)(\k<quote>)$", '$1' -split ':' |
        ? {$_ -ne '$PATH'} | Write-Output | Select-Object -Unique
    $PATH = $Expressions | ForEach-Object {$ExecutionContext.InvokeCommand.ExpandString($_)}
    $PATH += $env:PATH -split ':'
    $PATH = $PATH | Select-Object -Unique
    $env:PATH = @($PATH) -ne '' -join ':'
    Remove-Variable PATH, NixProfiles, NixPathLines, Expressions
}

$env:PYTHONSTARTUP = Resolve-Path ~/.pyrc -ErrorAction Ignore

#region PWD
function Test-VSCode
{
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
    return $Global:IsVSCode
}

$env:GITROOT = if (Test-Path /gitroot) {"/gitroot"} elseif (Test-Path ~/gitroot) {"~/gitroot"}

if ($env:GITROOT -and -not (Test-VSCode))
{
    Set-Location $env:GITROOT
}
#endregion PWD

if (Get-Command starship -ErrorAction Ignore)
{
    # brew install starship / choco install starship / winget install Starship.Starship
    $env:STARSHIP_CONFIG = $PSScriptRoot | Split-Path | Join-Path -ChildPath starship.toml
    starship init powershell --print-full-init | Out-String | Invoke-Expression
}

if (Get-Command carapace -ErrorAction Ignore) {
    $env:CARAPACE_NOSPACE = "*"
    $env:CARAPACE_MATCH = 1
    $env:CARAPACE_BRIDGES = 'zsh,fish,bash,inshellisense' # optional
    carapace _carapace | Out-String | Invoke-Expression
}

$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'

$AsyncProfile = {
    . "{{ .chezmoi.sourceDir }}/PSHelpers/Console.ps1"
    . "{{ .chezmoi.sourceDir }}/PSHelpers/git_helpers.ps1"
    . "{{ .chezmoi.sourceDir }}/PSHelpers/pipe_operators.ps1"
    . "{{ .chezmoi.sourceDir }}/PSHelpers/Utils.ps1"
    {{ if eq .chezmoi.os "linux" }}. "{{ .chezmoi.sourceDir }}/PSHelpers/LinuxNetworking.ps1"
    {{ end }}. "{{ .chezmoi.sourceDir }}/PSHelpers/ModuleLoad.ps1"

    if (Import-Module PSFzf -PassThru -ea Ignore)
    {
        Set-PsFzfOption -PSReadlineChordProvider Ctrl+f
    }

    if (Test-Path "{{ .chezmoi.sourceDir }}/Work/work_profile.ps1")
    {
        . "{{ .chezmoi.sourceDir }}/Work/work_profile.ps1"
    }
}

if (Import-Module ProfileAsync -PassThru -ea Ignore)
{
    $splat = if ((Get-Command Import-ProfileAsync).Parameters.LogPath) {@{LogPath = "/gitroot/ProfileAsync.log"}} else {@{}}
    Import-ProfileAsync $AsyncProfile @splat
}
else
{
    . $AsyncProfile
}
