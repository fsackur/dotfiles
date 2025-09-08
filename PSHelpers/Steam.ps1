
$env:STEAM_PATH = "~/.local/share/Steam/steamapps" | Resolve-Path

$Script:SteamAppIds = @{}

function Get-SteamApp {
    [CmdletBinding()]
    param (
        [SupportsWildcards()]
        [Alias('Name')]
        [string]$App
    )

    [int]$AppId = 0
    if ([int]::TryParse($App, [ref]$AppId)) {
        $Files = gci $env:STEAM_PATH -Filter "appmanifest_$AppId.acf"
        $Manifests = $Files | Read-AppManifest
    } elseif ($Script:SteamAppIds.Keys.Count) {
        $Names = $Script:SteamAppIds.Keys -like $App
        $Ids = $Script:SteamAppIds.Values -like $App
        if ($Names) {
            $Ids += @($Names | % {$Script:SteamAppIds[$_]})
        }

        $Ids

        $Files = if ($Ids) {
            $Ids
                | % {$Script:SteamAppIds[$_]}
                | % {gci $env:STEAM_PATH -Filter "appmanifest_$_.acf"}
        }
    }

    if ($Files) {
        $Manifests = $Files | Read-AppManifest
    } else {
        $Files = gci $env:STEAM_PATH -Filter "appmanifest_*.acf"
        $Manifests = $Files | Read-AppManifest
        $Manifests | % {$Script:SteamAppIds[$_.name] = $_.appid}
    }

    if ($App) {
        $Manifests | ? {$_.appid -like $App -or $_.name -like $App}
    } else {
        $Manifests
    }
}

Register-ArgumentCompleter -CommandName Get-SteamApp -ParameterName App -ScriptBlock {
    param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    if (-not $Script:SteamAppIds.Keys.Count) {
        $null = Get-SteamApp
    }
    $Names = ($Script:SteamAppIds.Keys | Sort-Object), ($Script:SteamAppIds.Values | Sort-Object) | Write-Output
    $Completions = (@($Names) -like "$wordToComplete*"), (@($Names) -like "*$wordToComplete*") | Write-Output | Select-Object -Unique
    $Completions -replace '^(.*\s.*)$', "'`$1'"
}

function Read-SteamAppManifest {
    param (
        [Parameter(Mandatory, Position=0, ValueFromPipeline)]
        [string]$Path
    )

    begin {
        function rec {
            param (
                [Parameter(Mandatory, Position=0)]
                [System.Collections.IEnumerator]$e
            )

            $Key = $Value = $null
            [long]$NumericValue = 0
            $Output = [ordered]@{}

            while ($e.MoveNext()) {
                $Line = $e.Current

                $Line = $Line.TrimStart()

                if ($Line -eq "{") {
                    if ($null -eq $Key) {
                        throw "Open object without key: $Line"
                    }
                    $Value = rec $e
                    if ($Key -notmatch "Depots") {
                        $Value = [pscustomobject]$Value
                    }

                } elseif ($Line -eq "}") {
                    return $Output

                } else {
                    $Head, $Tail = $Line -split "(\t|\n)+" | % Trim | ? Length
                    # "head: '$Head', tail: '$Tail'"


                    if ($Tail -is [array]) {
                        throw "Unexpected multiple values: $Line"
                    }
                    if ($null -eq $Tail) {
                        if ($null -eq $Key) {
                            $Key = $Head | unquote
                            continue
                        } else {
                            $Value = $Head | unquote
                        }
                    } else {
                        $Key = $Head | unquote
                        $Value = $Tail | unquote
                    }
                }

                if (
                    ($Key -notmatch 'LastOwner|BuildID') -and
                    ($Value -is [string]) -and
                    ([long]::TryParse($Value, [ref]$NumericValue))
                ) {
                    $Value = $NumericValue

                    if (1700000000 -lt $Value -and $Value -lt 1800000000) {
                        $Value = [datetime]::UnixEpoch.AddSeconds($Value)

                    } elseif ($Key -match 'SizeOnDisk|Bytes') {
                        $Value = $Value / 1MB
                        $Key = $Key -replace "SizeOnDisk", "SizeOnDiskMB" -replace "Bytes", "MB"
                    }
                }

                if (($null -eq $Key) -and ($null -eq $Value)) {
                    throw "Unexpected: key is '$Key', value is '$Value': '$Line'"
                }
                $Output[$Key] = $Value
                $Key = $Value = $null
            }

            return $Output
        }
    }

    process {
        $Lines = Get-Content $Path
        $Manifest = rec $Lines.GetEnumerator()
        if ($Manifest.Keys.Count -ne 1) {
            throw "$($Manifest.Keys)"
        }
        $Manifest.AppState
    }
}
