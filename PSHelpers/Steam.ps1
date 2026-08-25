
$env:STEAM_PATH = "~/.local/share/Steam/steamapps" | Resolve-Path

$Script:SteamAppIds = @{}

$Script:SteamWineBase = Join-Path $env:STEAM_PATH compatdata
$Script:WineBase = "~/.local/share/wine" | Resolve-Path
$Script:WinePrefixStack = [Collections.Generic.Stack[string]]::new()

function Initialize-SteamAppId {
    [CmdletBinding()]
    param ()

    if ($Script:SteamAppIds.Keys.Count) {
        return
    }

    $Files = gci $env:STEAM_PATH -Filter "appmanifest_*.acf"
    $Pattern = "^\s*`"(?<field>appid|name)`"\s+`"(?<value>.*)`"$"

    foreach ($File in $Files) {
        Get-Content $File -First 10 | % {
            if ($_ -match $Pattern) {
                Set-Variable -Name $Matches.field -Value $Matches.value
            }
        }

        if ($Name -and $AppId) {
            $Script:SteamAppIds[$Name] = $AppId
        } else {
            Write-Error "Failed to parse appid and name from $File"
        }
    }
}

function Get-SteamAppId {
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [SupportsWildcards()]
        [Alias('Name')]
        [Alias('AppId')]
        [string]$App
    )

    begin {
        Initialize-SteamAppId
    }

    process {
        $Ids = @($Script:SteamAppIds.Values -like $App)
        if ($Ids) {
            $Ids
        } else {
            $Names = @($Script:SteamAppIds.Keys -like $App)
            if ($Names) {
                $Names | % {$Script:SteamAppIds[$_]}
            }
        }
    }
}

function Get-SteamApp {
    [CmdletBinding()]
    param (
        [SupportsWildcards()]
        [Alias('Name')]
        [string]$App
    )

    [int]$AppId = 0

    $Files = if ([int]::TryParse($App, [ref]$AppId)) {
        gci $env:STEAM_PATH -Filter "appmanifest_$AppId.acf"

    } else {
        Initialize-SteamAppId

        Get-SteamAppId $App | % {gci $env:STEAM_PATH -Filter "appmanifest_$_.acf"} | Sort-Object -Unique
    }

    Write-Debug "Found $($Files.Count) app manifests"

    if (-not $Files) {
        $Files = gci $env:STEAM_PATH -Filter "appmanifest_*.acf"
    }

    Write-Debug "Found $($Files.Count) app manifests"

    $Manifests = $Files | Read-SteamAppManifest
    Write-Debug "Parsed $($Manifests.Count) app manifests"
    $Manifests | % {$Script:SteamAppIds[$_.name] = $_.appid}

    if ($App) {
        $Manifests | ? {$_.appid -like $App -or $_.name -like $App}
    } else {
        $Manifests
    }
}

function Read-SteamAppManifest {
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
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

                Write-Debug "Parsing: $Line"

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

function Get-SteamAppLocation {
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName, ValueFromPipeline)]
        [SupportsWildcards()]
        [Alias('Name')]
        [Alias('AppId')]
        [object]$App,

        [ValidateSet("AppPath", "WinePrefix", "WineUserProfile")]
        [string]$Location = "AppPath"
    )

    process {
        $AppId = if ($App.appid) {
            $App.appid
        } else {
            Get-SteamAppId $App
        }

        if (@($AppId).Count -gt 1) {
            throw "Ambiguous match for '$app': $($AppId -join ", ")"
        } elseif (-not $AppId) {
            throw [System.Management.Automation.ItemNotFoundException]::new("No match found for '$App'")
        }

        $WinePrefix = [IO.Path]::Join($SteamWineBase, $AppId, "pfx")

        if ($Location -eq "WineUserProfile") {
            [IO.Path]::Join($WinePrefix, "/drive_c/users/steamuser")

        } elseif ($Location -eq "WinePrefix") {
            $WinePrefix

        } elseif ($Location -eq "AppPath") {
            $SteamApp = Get-SteamApp $AppId
            $Dir = $SteamApp.installdir
            [IO.Path]::Join($env:STEAM_PATH, "common", $Dir)
        }
    }
}

function Push-SteamAppLocation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName, ValueFromPipeline)]
        [SupportsWildcards()]
        [Alias('Name')]
        [Alias('AppId')]
        [object]$App,

        [ValidateSet("AppPath", "WinePrefix", "WineUserProfile")]
        [string]$Location = "AppPath"
    )

    begin {
        $Flags = [Reflection.BindingFlags]"Instance,NonPublic"

        $ContextField = [Management.Automation.EngineIntrinsics].GetField("_context", $Flags)
        $ec = $ContextField.GetValue($ExecutionContext)
        $TlssProperty = $ec.GetType().GetProperty("TopLevelSessionState", $Flags)
        $Ssi = $TlssProperty.GetValue($ec)

        $SsiType = $Ssi.GetType()
        $PushMethod = $SsiType.GetMethod("PushCurrentLocation", $Flags)
        $SetMethod = $SsiType.GetMethod("SetLocation", $Flags, ([type[]]@([string])))

        $StackField = $SsiType.GetField("_defaultStackName", $Flags)
        $StackName = $StackField.GetValue($Ssi)
    }

    process {
        $Path = Get-SteamAppLocation @PSBoundParameters

        $PushMethod.Invoke($Ssi, @($StackName))
        $null = $SetMethod.Invoke($Ssi, @($Path))
    }
}

function Get-WinePrefix {
    param (
        [Parameter(Position = 0, ValueFromPipeline)]
        [SupportsWildcards()]
        [Alias('Name')]
        [Alias('AppId')]
        [object]$App
    )

    process {
        if ($PSBoundParameters.ContainsKey("App")) {
            if ($App.AppId) {$App = $App.AppId}
            gci $SteamWineBase, $WineBase -Filter $App
        } else {
            gci $SteamWineBase, $WineBase
        }
    }
}

function Push-WinePrefix {
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName, ValueFromPipeline)]
        [SupportsWildcards()]
        [Alias('App')]
        [Alias('AppId')]
        [object]$Name
    )

    try {
        $WinePrefix = $Name | Get-SteamAppLocation -Location WinePrefix -ea Stop
    } catch [System.Management.Automation.ItemNotFoundException] {
        $WinePrefix = $Name | Get-WinePrefix
    }

    if (-not $WinePrefix) {
        throw [System.Management.Automation.ItemNotFoundException]::new("No match found for '$Name'")
    }

    $WinePrefixStack.Push($env:WINEPREFIX)
    $env:WINEPREFIX = $WinePrefix
}

function Pop-WinePrefix {
    $env:WINEPREFIX = $WinePrefixStack.Pop()
}

function New-WinePrefix {
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName, ValueFromPipeline)]
        [string]$Name,

        [ValidateSet("win11", "win10", "win81", "win8", "win2008r2", "win7", "win2008", "vista", "win2003", "winxp64", "winxp", "win2k", "winme", "win98", "win95", "nt40", "nt351", "win31", "win30", "win20")]
        [string]$Version = "win10"
    )

    process {
        $WinePrefix = Join-Path $Script:WineBase $Name

        if (-not ((Join-Path $WinePrefix drive_c) | Test-Path)) {
            New-Item $WinePrefix -ItemType Directory -Force

            Push-WinePrefix $Name -ea Stop
            try {
                winecfg /v $Version
            } finally {
                Pop-WinePrefix
            }
        }
    }
}

function Install-WineApp {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
    param (
        [Parameter(Mandatory, Position = 0)]
        [Alias('Prefix')]
        [string]$Name,

        [Parameter(Mandatory, Position = 1)]
        [string]$Path
    )


    # New-WinePrefix $Name
    # Push-WinePrefix $Name

    # Push-Location $env:WINEPREFIX

    # try {
    #     [string[]]$DefaultFiles = gci ./drive_c/ -Exclude windows | gci -File -Recurse -Filter *.exe

    #     # install
    #     wine $Path

    #     $ChangedFiles = gci ./drive_c/ -Exclude windows | gci -File -Recurse -Filter *.exe | ? {$_.FullName -notin $DefaultFiles}

    # } finally {
    #     Pop-Location
    # }

    $ChangedFiles = (
        '/home/freddie/.local/share/wine/zelotes/drive_c/Program Files (x86)/ZELOTES C-18/Monitor.exe',
        '/home/freddie/.local/share/wine/zelotes/drive_c/Program Files (x86)/ZELOTES C-18/Option.exe',
        '/home/freddie/.local/share/wine/zelotes/drive_c/Program Files (x86)/ZELOTES C-18/Osd.exe',
        '/home/freddie/.local/share/wine/zelotes/drive_c/Program Files (x86)/ZELOTES C-18/unins000.exe'
    ) | gi

    if ($ChangedFiles) {
        "The following exe files were created:", $ChangedFiles | Write-Output | Write-Host -ForegroundColor Cyan
    }

    $DesktopBase = "~/.local/share/applications" | Resolve-Path  # or /usr/share/applications/

    $ShouldUpdateDesktopDb = $false

    $ChangedFiles | % {
        $Path = $_.FullName
        $_Name = $_.BaseName

        $DesktopPath = Join-Path $DesktopBase "$_Name.desktop"
        if (-not (Test-Path $DesktopPath) -and $PSCmdlet.ShouldProcess($Path, "Create desktop application")) {
            $Exec = "WINEPREFIX='$env:WINEPREFIX' wine '$Path'"
            $Content = "
                [Desktop Entry]
                Name=$_Name
                Exec=$Exec
                Terminal=false
                Icon=winetricks
                Type=Application
                Categories=Utility;
            " -replace "(?<=^|\n)\s+"

            $Content > $DesktopPath

            $ShouldUpdateDesktopDb = $true
        }
    }

    if ($ShouldUpdateDesktopDb) {
        sudo update-desktop-database
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
