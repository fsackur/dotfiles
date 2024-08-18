
#region private

function Get-DconfPath
{
    [CmdletBinding()]
    param
    (
        [switch]$Refresh
    )

    if ($Refresh -or -not $Script:DconfPaths)
    {
        $Dump = dconf dump /
        $Script:DconfPaths = $Dump |
            Select-String '^\[(?<path>.*)\]$' |
            ForEach-Object Matches |
            ForEach-Object Groups |
            Where-Object Name -eq "path" |
            ForEach-Object Value
    }
    $Script:DconfPaths
}

function Resolve-DconfPath
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, Position = 0)]
        [string]$Path,

        [Parameter(ValueFromPipeline, Mandatory, Position = 1)]
        [AllowEmptyString()]
        [string]$Text
    )

    process
    {
        $Lines = $Text -split '\r?\n'
        foreach ($Line in $Lines)
        {
            if ($Line -match '^\[(?<Path>.+)\]\s*$')
            {
                $_Path = $Path, $Matches.Path -join '/' -replace '/{2,}', '/' -replace '/$'
                "[$_Path]"
            }
            else
            {
                $Line
            }
        }
    }

    end {""}
}

#endregion private

#region public

function Export-Dconf
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, Position = 0)]
        [string[]]$Path
    )

    foreach ($_Path in $Path)
    {
        $_Path = $_Path -replace '^/?', '/' -replace '(?<=[^/])$', '/'
        dconf dump $_Path | Resolve-DconfPath -Path $_Path
    }
}

Register-ArgumentCompleter -CommandName Export-Dconf -ParameterName Path -ScriptBlock {
    param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    $Paths = Get-DconfPath
    (@($Paths) -like "$wordToComplete*"), (@($Paths) -like "*$wordToComplete*") | Write-Output
}

function Import-Dconf
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 0)]
        [string]$Path = '/',

        [Parameter(Mandatory, ValueFromPipeline, Position = 1)]
        [AllowEmptyString()]
        [string[]]$InputObject
    )

    end
    {
        $Path = $Path -replace '^/?', '/' -replace '(?<=[^/])$', '/'
        $_Path = $Path

        if ($MyInvocation.ExpectingInput)
        {
            $InputObject = $input
        }

        # Can't get past error: "Key file contains line [some_group] which is not a key-value pair, group, or comment"
        # So we use dconf write instead of dconf load
        $Lines = ($InputObject | Out-String).Trim() -split '\r?\n'
        foreach ($Line in $Lines)
        {
            if ([string]::IsNullOrWhiteSpace($Line) -or $Line.StartsWith('#'))
            {
                continue
            }
            elseif ($Line -match '^\[(?<Path>.+)\]\s*$')
            {
                $__Path = $Matches.Path
                $_Path = if ($__Path -eq '/')
                {
                    $Path -replace '/$'
                }
                elseif ($__Path -match '^/.')
                {
                    $__Path
                }
                else
                {
                    $Path, $__Path -join '/' -replace '/{2,}', '/'
                }
            }
            else
            {
                $Key, $Value = $Line -split '=', 2
                $FullKey = $_Path, $Key -join '/' -replace '/{2,}', '/'
                dconf write $FullKey "$Value"
                if (-not $?)
                {
                    Write-Error "Failed to write '$Value' to '$FullKey'"
                }
            }
        }
    }
}

#endregion public
