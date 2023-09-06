function Test-ThunderbirdClosed
{
    $Platform = [environment]::OSVersion.Platform
    if ($Platform -match 'Win')
    {
        return -not (Get-Process thunderbird -ErrorAction Ignore)
    }
    throw [NotImplementedException]::new("Not tested on $Platform")
}

function Export-ThunderbirdFilters
{
    if (-not (Test-ThunderbirdClosed))
    {
        throw "Thunderbird is running!"
    }

    $Platform = [environment]::OSVersion.Platform
    $DataPath = if ($Platform -match 'Win')
    {
        Join-Path $env:APPDATA Thunderbird
    }
    $ProfileIni = Join-Path $DataPath profiles.ini
}
