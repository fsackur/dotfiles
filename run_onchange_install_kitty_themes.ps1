#! /usr/bin/pwsh

$ErrorActionPreference = 'Stop'

$ConfDir = "~/.config/kitty/"
$ThemeDir = Join-Path $ConfDir kitty-themes
if (-not (Test-Path $ThemeDir)) {
    $null = New-Item -ItemType Directory -Force $ConfDir
    git clone https://github.com/dexpota/kitty-themes $ThemeDir
}
