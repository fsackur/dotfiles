$Script:KnownDevices = @{
    "ghetto-blaster" = @{
        $Headphones = "alsa_output.usb-MediaTek_Inc_Razer_BlackShark_V2_HS_2.4_0000000000000000-00.iec958-stereo"
        $Speakers = "alsa_output.pci-0000_0b_00.1.hdmi-stereo-extra1"
    }
}

function Get-PulseAudioDevice {
    [CmdletBinding(DefaultParameterSetName = "All")]
    param (
        [Parameter(ParameterSetName = "Sink")]
        [switch]$Sink,

        [Parameter(ParameterSetName = "Source")]
        [switch]$Source,

        [Parameter(ParameterSetName = "Default")]
        [switch]$Default,

        [Parameter(ParameterSetName = "All")]
        [switch]$All
    )

    $PulseAudio = pactl --format json list | ConvertFrom-Json
    $Devices = if ($PSCmdlet.ParameterSetName -eq "Sink") {
        $PulseAudio.sinks
    } elseif ($PSCmdlet.ParameterSetName -eq "Source") {
        $PulseAudio.sources
    } elseif ($PSCmdlet.ParameterSetName -eq "All") {
        $PulseAudio.sinks, $PulseAudio.sources | Write-Output
    } elseif ($PSCmdlet.ParameterSetName -eq "Default") {
        $Name = pactl get-default-sink
        $PulseAudio.sinks | ? name -eq $Name
    } else {
        throw [NotImplementedException]::new("No code path for '$($PSCmdlet.ParameterSetName)'")
    }

    $Devices | % {$_.PSTypeNames.Insert(0, "PulseAudioDevice")}
    $Devices
}

function Set-PulseAudioDefaultSink {
    # https://shallowsky.com/linux/pulseaudio-command-line.html
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Sink')]
        [string]$Name
    )

    pactl set-default-sink $Name
}

Register-ArgumentCompleter -CommandName Set-PulseAudioDefaultSink -ParameterName Name -ScriptBlock {
    param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    if (-not $Script:PulseAudioDevices) {
        $Script:PulseAudioDevices = Get-PulseAudioDevice -All
    }
    $Names = $Script:PulseAudioDevices.name
    $Completions = (@($Names) -like "$wordToComplete*"), (@($Names) -like "*$wordToComplete*") | Write-Output | Select-Object -Unique
    $Completions -replace '^(.*\s.*)$', "'`$1'"
}
