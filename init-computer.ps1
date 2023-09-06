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
    winget install Bitwarden.cli
}

$env:BW_SESSION = bw unlock --raw *>&1
if (-not $?)
{
    $env:BW_SESSION = bw login --raw
}

$FolderId = bw list folders --search SSH | ConvertFrom-Json | ? name -eq "SSH" | % id
$SshSecrets = bw list items --folderid $FolderId | ConvertFrom-Json
$SshSecrets | ? name -eq "config" | % notes >> ~/.ssh/config
$SshSecrets | ? name -ne "config" | % {
    $KeyName = $_.name
    $_.login.username > ~/.ssh/$KeyName.pub
    $_.notes > ~/.ssh/$KeyName
}

chezmoi init fsackur/dotfiles --ssh --branch chezmoi --recurse-submodules=false --apply
