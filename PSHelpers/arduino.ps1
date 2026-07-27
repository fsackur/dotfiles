#requires -Modules pipe_operators  # pipeline use of match, split, etc

if (-not (gcm arduino-cli -ErrorAction Ignore)) {throw "arduino-cli not found."}

#region config
$ConfigKeys = (
    "board_manager.additional_urls",
    "board_manager.enable_unsafe_install",
    "build_cache.compilations_before_purge",
    "build_cache.extra_paths",
    "build_cache.path",
    "build_cache.ttl",
    "daemon.port",
    "directories.data",
    "directories.downloads",
    "directories.user",
    "library.enable_unsafe_install",
    "locale",
    "logging.file",
    "logging.format",
    "logging.level",
    "metrics.addr",
    "metrics.enabled",
    "network.cloud_api.skip_board_detection_calls",
    "network.connection_timeout",
    "network.proxy",
    "output.no_color",
    "sketch.always_export_binaries",
    "updater.enable_notification"
)

function Get-ArduinoCliConfig {
    [CmdletBinding()]
    param (
        [string]$Key
    )

    $ErrorActionPreference = "Stop"

    if (-not $Key) {
        arduino-cli config dump
        return
    }

    arduino-cli config get $Key | match .
}

function Set-ArduinoCliConfig {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0)]
        [string]$Key,

        [Parameter(Mandatory, Position = 1)]
        [string]$Value
    )

    $ErrorActionPreference = "Stop"

    if ($Value -match "\s") {$Value = "'$Value'"}

    arduino-cli config set $Key $Value
}
#endregion config

#region boards
$InstalledBoards = $null
$DefaultBoard = $null
# $DefaultBoard = "arduino:renesas_uno:nanor4"

class Board {
    [string]$Port
    [string]$Protocol
    [string]$Type
    [string]$BoardName
    [string]$Fqbn
    [string]$Core
    [string] ToString() {return $this.Fqbn}
}
[string[]]$BoardFields = [Board].GetProperties() | % Name
[string[]]$BoardCliFields = $BoardFields -replace "BoardName", "Board Name" -replace "Fqbn", "FQBN"

function local:ConvertTo-ArduinoBoard {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [AllowEmptyString()]
        [string[]]$CliOutput
    )

    if ($MyInvocation.ExpectingInput) {
        $CliOutput = $input
    }

    $Output = $CliOutput | match .
    $Header = $Output[0]

    [string[]]$_BoardFields = $Script:BoardFields
    [int[]]$Indices = $Script:BoardCliFields | % {$Header.IndexOf($_)}

    # strip fields not present in header row
    $Tuples = [System.Linq.Enumerable]::Zip($_BoardFields, $Indices) | ? Item2 -ge 0
    [string[]]$_BoardFields = $Tuples | % Item1
    $Indices = $Tuples | % Item2
    $Offsets = [System.Linq.Enumerable]::Skip($Indices, 1)

    foreach ($Line in ($Output | select -Skip 1)) {
        $Values = @{}
        [System.Linq.Enumerable]::Zip($_BoardFields, $Indices, $Offsets) | % { # last field is missing
            $Field = $_.Item1
            $Index = $_.Item2
            $Length = $_.Item3 - $Index
            if ($Index -ge 0) {
                $Values[$Field] = $Line.Substring($Index, $Length).TrimEnd()
            }
        }
        # add back missing last field
        $Values[$_BoardFields[-1]] = $Line.Substring($Indices[-1]).TrimEnd()
        [Board]$Values
    }
}


function Get-ArduinoBoard {
    [CmdletBinding()]
    param (
        [switch]$Installed,

        [switch]$Flush
    )

    if ($Installed) {
        if ($Flush -or -not $Script:InstalledBoards) {
            $Script:InstalledBoards = arduino-cli board listall
                | ConvertTo-ArduinoBoard
                | Sort-Object Fqbn, BoardName

        }
        $Script:InstalledBoards

    } else {
        arduino-cli board list | ConvertTo-ArduinoBoard
    }
}

function Get-ArduinoDefaultBoard {
    [CmdletBinding()]
    param (
        [switch]$Flush
    )

    if ($Flush -or -not $Script:DefaultBoard) {
        $_Boards = Get-ArduinoBoard

        if (-not $_Boards) {
            throw "No boards connected. Set default board with Set-ArduinoDefaultBoard."
        }
        if ($_Boards.Count -ge 2) {
            throw "Multiple boards connected. Set default board with Set-ArduinoDefaultBoard."
        }
        $Script:DefaultBoard = $_Boards[0]
    }
    $Script:DefaultBoard
}

function Set-ArduinoDefaultBoard {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0)]
        [string]$Board
    )
    $Script:DefaultBoard = $Board
}
#endregion boards

#region serial

# arduino-cli monitor -p /dev/ttyACM0 --config 115200

#endregion serial

#region sketches
$ProjectRoot = Join-Path $env:GITROOT arduino | Resolve-Path -ErrorAction Stop

function Find-ArduinoSketch {
    [CmdletBinding()]
    param ()

    gci $ProjectRoot -Directory -Exclude libraries, .*
        | gci -Recurse -File -Filter *.ino
        | ? {$_.BaseName -eq (Split-Path -Leaf $_.Directory)}
        | % {[IO.Path]::GetRelativePath($ProjectRoot, $_)}
        | Split-Path
}

function Build-ArduinoSketch {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0)]
        [string]$Sketch,

        [string]$Board
    )

    Push-Location $ProjectRoot -ErrorAction Stop
    try {

        arduino-cli compile -b $Board $Sketch

    } finally {
        Pop-Location
    }
}

function Push-ArduinoSketch {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0)]
        [string]$Sketch,

        [string]$Board
    )

    Push-Location $ProjectRoot -ErrorAction Stop
    try {

        arduino-cli upload -b $Board $Sketch

    } finally {
        Pop-Location
    }
}

function Deploy-ArduinoSketch {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0)]
        [string]$Sketch,

        [string]$Board,

        [switch]$Watch
    )

    $Board
}
#endregion sketches

#region convenience
Set-Alias deploy Deploy-ArduinoSketch

Register-ArgumentCompleter -CommandName Get-ArduinoCliConfig, set-ArduinoCliConfig -ParameterName Key -ScriptBlock {
    param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    (@($ConfigKeys) -like "$wordToComplete*"), (@($ConfigKeys) -like "*$wordToComplete*") | Write-Output
}

Register-ArgumentCompleter -CommandName Build-ArduinoSketch, Push-ArduinoSketch, Deploy-ArduinoSketch -ParameterName Sketch -ScriptBlock {
    param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    $Sketches = Find-ArduinoSketch
    (@($Sketches) -like "$wordToComplete*"), (@($Sketches) -like "*$wordToComplete*") | Write-Output
}

Register-ArgumentCompleter -CommandName Build-ArduinoSketch, Push-ArduinoSketch, Deploy-ArduinoSketch -ParameterName Board -ScriptBlock {
    param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    $Boards = Get-ArduinoBoard -Installed
    (@($Boards) -like "$wordToComplete*"), (@($Boards) -like "*$wordToComplete*") | Write-Output
}

if ($null -eq $Global:PSDefaultParameterValues) {$Global:PSDefaultParameterValues = @{}}
$Global:PSDefaultParameterValues["*-ArduinoSketch:Board"] = {Get-ArduinoDefaultBoard}
#endregion convenience
