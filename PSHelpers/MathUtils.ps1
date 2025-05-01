
function ConvertTo-Radians {
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [double]$Degrees
    )

    process {
        $Degrees = $Degrees % 360
        $Degrees * [Math]::PI / 180
    }
}

function ConvertTo-Degrees {
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [double]$Radians
    )

    process {
        $Degrees = $Radians * 180 / [Math]::Pi
        $Degrees % 360
    }
}


class TrigResult
{
    [double]$Degrees
    [double]$Radians
    [double]$Hypotenuse
    [double]$Opposite
    [double]$Adjacent
}

function Invoke-Trigonometry {
    [CmdletBinding(DefaultParameterSetName = "Degrees")]
    [OutputType([TrigResult])]
    param (
        [Parameter(ParameterSetName = "Degrees", Mandatory, Position = 0)]
        [double]$Degrees,

        [Parameter(ParameterSetName = "Radians", Mandatory, Position = 0)]
        [double]$Radians,

        [Parameter()]
        [double]$Hypotenuse = 1,

        [Parameter(ParameterSetName = "Ratio", Mandatory)]
        [Parameter(ParameterSetName = "Degrees")]
        [Parameter(ParameterSetName = "Radians")]
        [double]$Opposite,

        [Parameter(ParameterSetName = "Ratio", Mandatory)]
        [Parameter(ParameterSetName = "Degrees")]
        [Parameter(ParameterSetName = "Radians")]
        [double]$Adjacent
    )

    if ($PSBoundParameters.Keys.Count -gt 2) {throw "Over-specified"}

    if ($PSCmdlet.ParameterSetName -eq "Ratio") {
        $Radians = [Math]::Atan2($Opposite, $Adjacent)
        $Hypotenuse = [Math]::Sqrt(
            ($Opposite * $Opposite) +
            ($Adjacent * $Adjacent)
        )

    } else {
        if ($PSCmdlet.ParameterSetName -eq "Degrees") {
            $Radians = $Degrees | ConvertTo-Radians
        }

        # $SideParam = $PSBoundParameters.GetEnumerator() | ? Key -ne $PSCmdlet.ParameterSetName | % Key | Select-Object -First 1
        # switch ($SideParam) {
        #     ""
        # }
        $Sin = [Math]::Sin($Radians)
        $Cos = [Math]::Cos($Radians)
        $Tan = [Math]::Tan($Radians)

        if ($Opposite) {
            $Hypotenuse = $Opposite / $Sin
            $Adjacent = $Cos * $Hypotenuse
        } elseif ($Adjacent) {
            $Hypotenuse = $Adjacent / $Cos
            $Opposite = $Sin * $Hypotenuse
        } else {
            $Adjacent = $Cos * $Hypotenuse
            $Opposite = $Sin * $Hypotenuse
        }
    }

    if ($PSCmdlet.ParameterSetName -ne "Degrees") {
        $Degrees = $Radians | ConvertTo-Degrees
    }

    return [TrigResult]@{
        Degrees = $Degrees
        Radians = $Radians
        Hypotenuse = $Hypotenuse
        Opposite = $Opposite
        Adjacent = $Adjacent
    }
}

Set-Alias trig Invoke-Trigonometry
