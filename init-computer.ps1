#!/usr/bin/env pwsh
#
#   Usage:
#       iwr -UseBasicParsing https://raw.githubusercontent.com/fsackur/dotfiles/dev/init-computer.ps1 | % Content | iex
#

$ErrorActionPreference = 'Stop'

# $PSGetMinVersion = [version]'2.2'
# $PSGet = Import-Module -PassThru PowerShellGet
# if ($PSGet.Version -lt $PSGetMinVersion)
# {
#     Install-Module -AllowClobber -Force PowerShellGet
#     Import-Module -Force PowerShellGet -MinimumVersion $PSGetMinVersion
# }

if (-not (Get-Command winget -ErrorAction Ignore))
{
    Invoke-RestMethod aka.ms/getwinget -OutFile winget.msixbundle
    Add-AppxPackage .\winget.msixbundle
}
try
{
    $null = Get-Command winget -ErrorAction Stop
}
catch
{
    $_.ErrorDetails = "WinGet not found; you may need to restart your shell: $_"
    Write-Error -ErrorRecord $_ -ErrorAction Stop
}

if (-not (
    (Get-Command git -ErrorAction Ignore) -and
    (((git --version) -replace '(.* )?(?=\d+\.\d+\.\d+)' -replace '(?<=^\d+\.\d+\.\d+).*') -as [version]) -ge ([version]'2.30')
))
{
    winget install Git.Git
}

if (-not (Get-Command chezmoi -ErrorAction Ignore))
{
    winget install twpayne.chezmoi
}

if (-not (Get-Command bw -ErrorAction Ignore))
{
    $InstallPath = Join-Path $env:LOCALAPPDATA 'BitWarden CLI'
    $null = New-Item $InstallPath -ItemType Directory -Force
    $ZipPath = Join-Path $env:TEMP bitwarden-cli.zip
    iwr https://vault.bitwarden.com/download/?app=cli&platform=windows -OutFile $ZipPath
    Expand-Archive $ZipPath -DestinationPath $InstallPath
    Remove-Item $ZipPath
    $_Path = [Environment]::GetEnvironmentVariable('Path', 'User')
    $_Path = $_Path, $InstallPath -join [IO.Path]::PathSeparator
    [Environment]::SetEnvironmentVariable('Path', $_Path, 'User')
    $env:Path =  $env:Path, $InstallPath -join [IO.Path]::PathSeparator
}

$env:BW_SESSION = bw unlock --raw *>&1
if (-not $?)
{
    $env:BW_SESSION = bw login --raw
}

$FolderId = bw list folders --search SSH | ConvertFrom-Json | ? name -eq "SSH" | % id
$SshSecrets = bw list items --folderid $FolderId | ConvertFrom-Json
$SshSecrets | ? name -eq "config" | % notes >> ~/.ssh/config
$SshSecrets | ? name -eq "github_ed25519" | % login | % username >> ~/.ssh/github_ed25519.pub
$SshSecrets | ? name -eq "github_ed25519" | % login | % password >> ~/.ssh/github_ed25519

chezmoi init fsackur/dotfiles --ssh --branch chezmoi --recurse-submodules=false --apply

# if (-not (
#     (Get-Command pwsh -ErrorAction Ignore) -and
#     ((pwsh --version) -replace '.* ' -as [version]).Major -ge 7
# ))
# {
#     winget install Microsoft.PowerShell
# }
