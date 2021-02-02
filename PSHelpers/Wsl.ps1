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
