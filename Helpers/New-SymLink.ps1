function New-SymLink
{
    <#
        .SYNOPSIS
        Creates a symbolic link at Location pointing to Target. Windows-only. Requires admin.
    #>
    param
    (
        [Parameter(Mandatory)]
        [string]$Location,

        [Parameter(Mandatory)]
        [string]$Target
    )

    $Parent = Split-Path $Location
    $Leaf   = Split-Path $Location -Leaf
    if (-not $Parent) {$Parent = '.'}
    $null   = New-Item $Parent -ItemType Directory -Force -ErrorAction Stop

    $Location = Join-Path $Parent $Leaf
    $Target   = Resolve-Path $Target -ErrorAction Stop


    Write-Verbose "Creating link at '$Location' pointing to '$Target'"


    $Cmd = "mklink"
    if (Test-Path $Target -PathType Container) {$Cmd += "/D"}
    $Cmd = "$Cmd `"$Location`" `"$Target`""


    $StartInfo = [Diagnostics.ProcessStartInfo]::new("cmd", ("/C", $Cmd))
    $StartInfo.RedirectStandardError  = $true
    $StartInfo.RedirectStandardOutput = $true
    $StartInfo.UseShellExecute = $false
    $StartInfo.Verb = 'RunAs'

    $Global:Process = [Diagnostics.Process]::new()
    $Process.StartInfo = $StartInfo

    if ($Process.Start())
    {
        $Process.WaitForExit()
    }
    if (-not $?) {return}

    $Output      = $Process.StandardOutput.ReadToEnd()
    $ErrorOutput = $Process.StandardError.ReadToEnd()

    $Pattern = 'symbolic link created for (?<Location>.*) <<===>> (?<Target>.*)'
    if ($Output -match $Pattern)
    {
        [pscustomobject]$Matches | Select-Object Location, Target
    }
    else
    {
        Write-Warning $Output
    }

    if ($ErrorOutput)
    {
        Write-Error $ErrorOutput
    }
}
