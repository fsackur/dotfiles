
function ConvertTo-Sentence
{
    <#
        .SYNOPSIS
        Breaks a PS command name into words.
    #>
    [OutputType([string[]])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [string]$InputObject,

        [switch]$CapitaliseFirstWord
    )

    process
    {
        # split on dash or before upper-case letter that isn't followed by another upper-case
        $Words = $InputObject -csplit '-|(?<=\w)(?=[A-Z][^A-Z])'

        # Don't lower-case capitalised acronyms
        $ContainsLowercasePattern = [regex]'.*[a-z].*'
        $Words = $Words | ForEach-Object {
            $ContainsLowercasePattern.Replace($_, {$args[0].Value.ToLower()})
        }

        $TextInfo = (Get-Culture).TextInfo
        if ($CapitaliseFirstWord)
        {
            $Words[0] = $TextInfo.ToTitleCase($Words[0])
        }

        $PSCmdlet.WriteObject($Words)
    }
}

function New-HelpBlock
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [object]$InputObject
    )

    begin
    {
        $Builder = [Text.StringBuilder]::new()
    }

    process
    {
        [Management.Automation.CommandInfo[]]$Commands = $InputObject | Get-Command

        foreach ($Command in $Commands)
        {
            $Indent = ' ' * 4

            $Words = $Command.Name | ConvertTo-Sentence -CapitaliseFirstWord
            $Words[0] += 's'
            $Synopsis = $Words -join ' '

            $ParameterNames = $Command.Parameters.Keys | Where-Object {$_ -notin $CommonParameters}
            $OutputTypes = $Command.OutputType.Type

            [void]$Builder.AppendLine('<#')

            [void]$Builder.Append($Indent).AppendLine('.SYNOPSIS')
            [void]$Builder.Append($Indent).Append($Synopsis).AppendLine('.').AppendLine()

            [void]$Builder.Append($Indent).AppendLine('.DESCRIPTION')
            [void]$Builder.Append($Indent).Append($Synopsis).AppendLine('.').AppendLine()

            foreach ($ParameterName in $ParameterNames)
            {
                [void]$Builder.Append($Indent).Append('.PARAMETER ').AppendLine($ParameterName)
                $IndefiniteArticle = if ($ParameterName -match '^[aeiou]') {'an'} else {'a'}
                $ParameterSynopsis = ($ParameterName | ConvertTo-Sentence) -join ' '
                [void]$Builder.Append($Indent).Append('Provide ').Append($IndefiniteArticle).Append(' ').Append($ParameterSynopsis).AppendLine('.').AppendLine()
            }

            if ($OutputTypes)
            {
                [void]$Builder.Append($Indent).AppendLine('.OUTPUTS')
            }

            foreach ($OutputType in $OutputTypes)
            {
                $TypeName = if ($OutputType.Name -as [Type]) {$OutputType.Name.ToLower()} else {$OutputType.FullName}
                [void]$Builder.Append($Indent).Append('[').Append($TypeName).AppendLine(']').AppendLine()
            }

            # Remove the last newline
            $Builder.Length -= [Environment]::NewLine.Length

            [void]$Builder.AppendLine('#>')

            $Builder.ToString()
        }
    }
}

function Enable-BreakOnError
{
    Set-PSBreakpoint -Variable StackTrace -Mode Write
}

function Disable-BreakOnError
{
    Get-PSBreakpoint -Variable StackTrace | Remove-PSBreakpoint
}

# Save typing out [pscustomobject]
Add-Type 'public class o : System.Management.Automation.PSObject {}'

function New-Link
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, Position = 0)]
        [string]$Path,

        [Parameter(Mandatory, Position = 1)]
        [string]$Target,

        [ValidateSet('Junction', 'SymbolicLink')]
        [string]$LinkType,

        [switch]$DontResolveTarget
    )

    if (-not $DontResolveTarget)
    {
        $Target = $Target | Resolve-Path -ErrorAction Stop
    }

    if (-not $LinkType)
    {
        $_IsWindows = [Environment]::OSVersion.Platform -match 'Win'

        $LinkType = if ($_IsWindows -and (Test-Path $Target -PathType Container))
        {
            'Junction'
        }
        else
        {
            'SymbolicLink'
        }
    }

    New-Item -ItemType $LinkType $Path -Value $Target
}
