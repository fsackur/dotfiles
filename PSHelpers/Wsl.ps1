function Convert-WslPath
{
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline)]
        [string]$Path
    )

    process
    {
        $MNT = $WSL_C_MOUNTPOINT, '/' | ? {$_} | select -First 1

        $Path -replace 'C:', "$MNT`c" -replace '\\', '/'
    }
}

if ($IS_WSL)
{
    Invoke-Expression "$(thefuck --alias)"

    Set-Alias clip clip.exe

    function Convert-WslPath
    {
        [CmdletBinding()]
        param
        (
            [Parameter(ValueFromPipeline)]
            [string]$Path
        )

        process
        {
            $MNT = $WSL_C_MOUNTPOINT, '/' | ? {$_} | select -First 1

            $Path -replace 'C:', "$MNT`c" -replace '\\', '/'
        }
    }
}
else
{
    function Convert-WslPath
    {
        [CmdletBinding()]
        param
        (
            [Parameter(ValueFromPipeline)]
            [string]$Path
        )

        process
        {
            $MNT = $WSL_C_MOUNTPOINT, '/' | ? {$_} | select -First 1

            $Path -replace ("^" + [regex]::Escape($MNT) + "c"), "C:"
        }
    }
}
