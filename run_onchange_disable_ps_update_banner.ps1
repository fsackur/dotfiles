#! /usr/bin/pwsh

$Line = "POWERSHELL_UPDATECHECK='Off'"
if (-not (@(Get-Content /etc/environment -ErrorAction Ignore) -match "^$Line$")) {
    $Line | sudo tee -a /etc/environment | Out-Null
}
