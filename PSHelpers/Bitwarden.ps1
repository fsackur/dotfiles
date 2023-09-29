
function Unlock-Bw
{
    $env:BW_SESSION = bw unlock --raw *>&1
    if (-not $?)
    {
        $env:BW_SESSION = bw login --raw
    }
}
