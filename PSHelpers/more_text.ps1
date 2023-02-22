function objectify
{
    <#
        .SYNOPSIS
        Generates objects from named matches in a regex pattern.

        .PARAMETER Fallback
        What you want to happen on input that doesn't match the pattern.

        .EXAMPLE


        gc '.\Gaming\xcom 2.md' | objectify '(?<DisplayName>.*?)\s+(?<Name>\S+)$' -Fallback {[pscustomobject]@{DisplayName = $_; Name = $null}} | ft Disp*, Name
    #>
    param
    (
        [Parameter(ValueFromPipeline)]
        [string[]]$InputObject,

        [Parameter(Mandatory, Position = 0)]
        [string]$Pattern,

        [scriptblock]$Fallback = {$_ | Write-Error}
    )

    process
    {
        $InputObject | foreach {

            if ($_ -match $Pattern)
            {
                [pscustomobject]$Matches | select (@($Matches.Keys) -notmatch '^\d*$')
            }
            else
            {
                $_ | & $Fallback
            }
        }
    }
}
