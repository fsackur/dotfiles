function Get-NtpTime
{
    [OutputType([datetime])]
    [CmdletBinding()]
    param
    (
        [string]$Server = "time.nist.gov",

        [int]$Port = 13
    )

    if (-not $PSBoundParameters.ContainsKey('ErrorAction'))
    {
        $ErrorActionPreference = 'Stop'
    }

    $Client = [Net.Sockets.TcpClient]::new($Server, $Port)
    $Reader = [IO.StreamReader]::new($Client.GetStream())
    try
    {
        $Response  = $Reader.ReadToEnd()
        $UtcString = $Response.Substring(7, 17)
        $LocalTime = [datetime]::ParseExact(
            $UtcString,
            "yy-MM-dd HH:mm:ss",
            [cultureinfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::AssumeUniversal
        )
    }
    finally
    {
        $Reader.Dispose()
        $Client.Dispose()
    }
    $LocalTime
}

function Register-TimeSync
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [timespan]$RepetitionInterval = (New-TimeSpan -Minutes 5),

        [Parameter()]
        [timespan]$ExecutionTimeLimit = (New-TimeSpan -Minutes 3)
    )

    $Invocation = {
        $NtpTime = Get-NtpTime
        $Delta   = [datetime]::Now - $NtpTime
        if ([Math]::Abs($Delta.TotalSeconds) -gt 30)
        {
            Set-Date $NtpTime
        }
    }

    $Pwsh       = (Get-Command pwsh).Source
    $Command    = Get-Command Get-NtpTime
    $Definition = "function Get-NtpTime`n{$($Command.Definition)}"
    $Invocation = $Definition, $Invocation -join "`n"
    $Bytes      = [Text.Encoding]::Unicode.GetBytes($Invocation)
    $Encoded    = [Convert]::ToBase64String($Bytes)

    $TriggerParams = @{
        Once               = $true
        At                 = [datetime]::Today
        RepetitionInterval = $RepetitionInterval
    }
    $Trigger   = New-ScheduledTaskTrigger @TriggerParams
    $Action    = New-ScheduledTaskAction -Execute $Pwsh -Argument "-NoProfile -EncodedCommand $Encoded"
    $Settings  = New-ScheduledTaskSettingsSet -ExecutionTimeLimit $ExecutionTimeLimit -MultipleInstances IgnoreNew
    $Principal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest

    $RegisterParams = @{
        TaskName  = "Update system time from NTP"
        Trigger   = $Trigger
        Action    = $Action
        Settings  = $Settings
        Principal = $Principal
        Force     = $true
    }

    Register-ScheduledTask @RegisterParams
}
