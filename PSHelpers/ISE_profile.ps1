

function Show-IseWindow
{
    param ($Files)

    $Files | %{$psISE.CurrentPowerShellTab.Files.Add((Resolve-Path $_))} | Out-Null
}

Set-Alias Show-Window Show-IseWindow -Scope Global -Force
Set-Alias ise Show-IseWindow -Scope Global -Force
