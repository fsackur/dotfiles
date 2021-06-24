function New-SymLink
{
    <#
        .SYNOPSIS
        Creates a symbolic link at Location pointing to Target. Windows-only. Requires admin.

        .DESCRIPTION
        This command creates a symbolic link in an NTFS filesystem on Windows. Links can be files or
        folders.

        The tool it uses is a 'mklink', which is a built-in command in cmd, so this command spawns
        an admin process running cmd.exe.

        Note that NTFS symlinks can error when you try to delete them:

        Remove-Item ~\Documents\WindowsPowerShell\Modules\DeveloperTools -Recurse -Force
        Remove-Item : There is a mismatch between the tag specified in the request and the tag present in the reparse point

        To work around this issue, you can call .Delete() on the FileInfo object:

        (Get-Item ~\Documents\WindowsPowerShell\Modules\DeveloperTools).Delete()

        You do not need to be running as admin to remove a symlink, only to create it.

        .PARAMETER Location
        The location for the new symlink. Folders that do not exist will be created.

        .PARAMETER Target
        The content that should be available elsewhere in a new symlink. This can be a file or a
        folder.

        .EXAMPLE
        New-Symlink -Location ~\Documents\WindowsPowerShell\Modules\DeveloperTools -Target C:\code\DeveloperTools

        Makes the contents of 'C:\code\DeveloperTools' available at '~\Documents\WindowsPowerShell\Modules\DeveloperTools'.
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
