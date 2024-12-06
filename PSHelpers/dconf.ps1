
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
        if (-not $?)
        {
            throw ($Dump | Out-String).Trim()
        }


        $KeyPaths = $Dump |
            Select-String '^\[(?<path>.*)\]$' |
            ForEach-Object Matches |
            ForEach-Object Groups |
            Where-Object Name -eq "path" |
            ForEach-Object Value

        $Last = ""
        $Script:DconfPaths = $KeyPaths | ForEach-Object {
            $Current = $_
            while ($Last -and $Current -notmatch "^$Last/.*")
            {
                $Last = $Last -replace '[^/]+?$' -replace '/$'
            }

            while ($Current -ne $Last)
            {
                $NextSegment = $Current -replace $Last -replace '^/' -replace '/.*'
                $Last = $Last, $NextSegment -join '/' -replace '^/'
                $Last
            }
        }
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
                $_Path = $Path, $Matches.Path -join '/' -replace '/{2,}', '/' -replace '^/' -replace '/$'
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

function Set-Dconf
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 0)]
        [string]$Path = '/',

        [Parameter(Mandatory, ValueFromPipeline, Position = 1)]
        [AllowEmptyString()]
        [string[]]$InputObject,

        [string[]]$Filter
    )

    end
    {
        $Path = $Path -replace '^/?', '/' -replace '(?<=[^/])$', '/'
        $_Path = $Path

        if ($Filter)
        {
            $Filter = @($Filter) -replace '^/?', '/' -replace '(?<=[^/])$', '/'
        }

        if ($MyInvocation.ExpectingInput)
        {
            $InputObject = $input
        }

        # Can't get past error: "Key file contains line [some_group] which is not a key-value pair, group, or comment"
        # So we use dconf write instead of dconf load
        $Lines = ($InputObject | Out-String).Trim() -split '\r?\n'
        $ShouldSkip = $false
        foreach ($Line in $Lines)
        {
            if ([string]::IsNullOrWhiteSpace($Line) -or $Line.StartsWith('#'))
            {
                continue
            }
            elseif ($Line -match '^\[(?<Path>.+)\]\s*$')
            {
                $ShouldSkip = $false
                $_Path = $(
                    $MatchedPath = $Matches.Path
                    if ($MatchedPath -eq '/')
                    {
                        $Path -replace '/$'
                    }
                    elseif ($MatchedPath -match '^/.')
                    {
                        $MatchedPath
                    }
                    else
                    {
                        $Path, $MatchedPath -join '/' -replace '/{2,}', '/'
                    }
                )
                continue
            }

            if (-not $ShouldSkip)
            {
                if ($Filter -and -not ($Filter | Where-Object {$FullKey -ilike $_}))
                {
                    $ShouldSkip = $true
                    Write-Verbose "Skipping $Fullkey"
                }
            }

            if ($ShouldSkip) {continue}

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

#endregion private

#region public

function Export-Dconf
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 0)]
        [string[]]$Path = "/",

        [Parameter(Position = 1)]
        [string]$OutFile
    )

    $Content = @()

    foreach ($_Path in $Path)
    {
        $_Path = $_Path -replace '^/?', '/' -replace '(?<=[^/])$', '/'
        $Content += dconf dump $_Path | Resolve-DconfPath -Path $_Path
    }
    return $Content

    $Content = ($Content | Out-String).Trim()
    if ($OutFile)
    {
        $Content > $OutFile
    }
    elseif ($Content)
    {
        $Content
    }
}

function Import-Dconf
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, Position = 0)]
        [string]$Path,

        [string[]]$Filter,

        [switch]$SkipBackup,

        [string]$BackupPath = (Join-Path ([IO.Path]::GetTempPath()) "dconf.$([datetime]::UtcNow.Ticks).ini")
    )

    end
    {
        if (-not $SkipBackup)
        {
            Export-Dconf / -OutFile $BackupPath
            "Backed up dconf settings to $BackupPath" | Write-Host -ForegroundColor DarkYellow
        }

        Get-Content $Path -ErrorAction Stop | Set-Dconf #-Filter $Filter
    }
}

$Completer = {
    param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    $HasLeadingSlash = $wordToComplete -match '^/'
    $wordToComplete = $wordToComplete -replace '^/'
    $Paths = @(Get-DconfPath) -ilike "*$wordToComplete*"
    $DirectChildren = @($Paths) -imatch "^$wordToComplete([^/]*)$"
    $Paths = $DirectChildren, $Paths | Write-Output | Select-Object -Unique
    if ($HasLeadingSlash)
    {
        $Paths = @($Paths) -replace '^/?', '/'
    }
    $Paths
}
Register-ArgumentCompleter -CommandName Set-Dconf, Export-Dconf -ParameterName Path -ScriptBlock $Completer
Register-ArgumentCompleter -CommandName Import-Dconf -ParameterName Filter -ScriptBlock $Completer

#endregion public
