function Backup-InvisibleInc
{
    [CmdletBinding()]
    param
    (
        [string]$Path = $(
            if ($IsWindows)
            {
                Join-Path $env:HOME Documents/Klei/InvisibleInc/saves/savegame.lua
            }
        ),

        [string]$Destination = $(
            if ($IsWindows)
            {
                Join-Path $env:HOME Documents/Klei/InvisibleInc/saves/Backups
            }
        )
    )

    $null = Get-Item $Path -ErrorAction Stop

    $null = New-Item $Destination -ItemType Directory -Force -ErrorAction Stop

    $DestFile = Join-Path $Destination "$([datetime]::UtcNow.Ticks).lua"
    Copy-Item $Path $DestFile -Force
}
