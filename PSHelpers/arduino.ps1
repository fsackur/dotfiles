#requires -Modules pipe_operators  # pipeline use of match, split, etc

if (-not (gcm arduino-cli -ErrorAction Ignore)) {throw "arduino-cli not found."}

$ErrorActionPreference = "Stop"

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
$Ports = $null
$DefaultPort = $null
$DefaultBoard = $null
# $DefaultBoard = "arduino:renesas_uno:nanor4"

class Board {
    [string]$Name
    [string]$Fqbn
    [string] ToString() {return $this.Fqbn}
}

class Port {
    [string]$Port
    [string]$Protocol
    [string]$Id
    [Board[]]$Board
    [string] ToString() {return $this.Port}
}

function Get-ArduinoBoard {
    [CmdletBinding()]
    param (
        [switch]$Flush
    )

    if ($Flush -or -not $Script:InstalledBoards) {
        $Script:InstalledBoards =
            arduino-cli board listall --json
            | ConvertFrom-Json -AsHashtable
            | % boards
            | % {[Board]@{Fqbn = $_.fqbn; Name = $_.name}}
            | Sort-Object Fqbn, Name
    }
    $Script:InstalledBoards
}

function Get-ArduinoPort {
    [CmdletBinding()]
    param (
        [switch]$Flush
    )

    if ($Flush -or -not $Script:Ports) {
        $Script:Ports =
            arduino-cli board list --json
                | ConvertFrom-Json
                | % detected_ports
                | % {[Port]@{
                    Port = $_.port.address
                    Protocol = $_.port.protocol
                    Id = $_.port.hardware_id
                    Board = $_.matching_boards
                }}
    }
    $Script:Ports
}

function Get-ArduinoDefaultPort {
    [CmdletBinding()]
    param (
        [switch]$Flush
    )

    if ($Flush -or -not $Script:DefaultPort) {
        $Ports = Get-ArduinoPort -Flush:$Flush

        if (-not $Ports) {
            throw "No boards connected. Set default port with Set-ArduinoDefaultPort."
        }
        if ($Ports.Count -ge 2) {
            throw "Multiple boards connected. Set default port with Set-ArduinoDefaultPort."
        }
        $Script:DefaultPort = $Ports[0]
    }
    $Script:DefaultPort
}

function Set-ArduinoDefaultPort {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0)]
        [string]$Port
    )
    $_Port = Get-ArduinoPort | ? Port -ieq $Port
    if (-not $_Port) {throw "Port not connected: $Port"}
    $Script:DefaultPort = $_Port

    if ($Script:DefaultBoard -and $Script:DefaultBoard -notin $_Port.Board) {
        $Script:DefaultBoard = $null
    }
}

function Get-ArduinoDefaultBoard {
    [CmdletBinding()]
    param (
        [switch]$Flush
    )

    if ($Flush -or -not $Script:DefaultBoard) {
        $Port = Get-ArduinoDefaultPort

        $Boards = $Port.Board

        if (-not $Boards) {
            throw "No boards connected. Set default board with Set-ArduinoDefaultBoard."
        }
        if ($Boards.Count -ge 2) {
            throw "Multiple boards connected. Set default board with Set-ArduinoDefaultBoard."
        }
        $Script:DefaultBoard = $Boards[0]
    }
    $Script:DefaultBoard
}

function Set-ArduinoDefaultBoard {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0)]
        [string]$Board
    )
    $_Board = Get-ArduinoBoard | ? Fqbn -ieq $Board
    if (-not $_Board) {throw "Board not installed: $Board"}
    $Script:DefaultBoard = $_Board
}
#endregion boards

#region serial
function Connect-Arduino {
    param (
        [string]$Port = (Get-ArduinoDefaultPort),

        [int]$Baud = 115200,

        [switch]$Reconnect
    )

    $Connect = {arduino-cli monitor --quiet --port $Port --config $Baud}

    if (-not $Reconnect) {
        & $Connect
        if ($?) {
            return
        } else {
            throw "arduino-cli monitor exited with code $LASTEXITCODE."
        }
    }

    $Dir = Split-Path $Port
    $Device = Split-Path $Port -Leaf

    $Watcher = [IO.FileSystemWatcher]::new($Dir, $Device)

    try {
        while ($true) {
            if (-not (Test-Path $Port)) {
                Write-Host -ForegroundColor Cyan "Waiting for $Port..." -NoNewline

                [void]$Watcher.WaitForChanged("Created")

                Write-Host -ForegroundColor Cyan " detected."
            }

            & $Connect

            Start-Sleep -Milliseconds 20
        }

    } finally {
        $Watcher.Dispose()
    }
}
#endregion serial

#region sketches
$ProjectRoot = Join-Path (realpath $env:GITROOT) arduino | Resolve-Path -ErrorAction Stop

function Find-ArduinoSketch {
    [CmdletBinding()]
    param ()

    gci $ProjectRoot -Directory -Exclude libraries, .*
        | gci -Recurse -File -Filter *.ino
        | ? {$_.BaseName -eq (Split-Path -Leaf $_.Directory)}
        | % {[IO.Path]::GetRelativePath($ProjectRoot, $_)}
        | Split-Path
}

function Resolve-ArduinoSketch {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline, Position = 0)]
        [AllowEmptyString()]
        [string]$Sketch
    )

    process {
        if ($Sketch) {
            $Path = Join-Path $ProjectRoot $Sketch | Resolve-Path
        } else {
            $Path = $PWD | Resolve-Path
        }
        $Leaf = $Path | Split-Path -Leaf
        $Path | Join-Path -ChildPath "$Leaf.ino" | Resolve-Path | Out-Null
        [IO.Path]::GetRelativePath($ProjectRoot, $Path)
    }
}

function Build-ArduinoSketch {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [string]$Sketch,

        [string]$Board = (Get-ArduinoDefaultBoard)
    )

    $Sketch = Resolve-ArduinoSketch $Sketch
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
        [Parameter(Position = 0)]
        [string]$Sketch,

        [string]$Board = (Get-ArduinoDefaultBoard),

        [string]$Port = (Get-ArduinoDefaultPort)
    )

    $Sketch = Resolve-ArduinoSketch $Sketch
    Push-Location $ProjectRoot -ErrorAction Stop
    try {

        arduino-cli upload -p $Port -b $Board $Sketch

    } finally {
        Pop-Location
    }
}

function Deploy-ArduinoSketch {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [string]$Sketch,

        [string]$Board = (Get-ArduinoDefaultBoard),

        [string]$Port = (Get-ArduinoDefaultPort),

        [switch]$Watch
    )

    $Sketch = Resolve-ArduinoSketch $Sketch

    Write-Host "Building..."
    Build-ArduinoSketch $Sketch -Board $Board
    Push-ArduinoSketch $Sketch -Board $Board -Port $Port

    if (-not $Watch) {return}

    $Path = Join-Path $Script:ProjectRoot $Sketch
    $Watcher = [IO.FileSystemWatcher]::new($Path)

    try {
        "...done. Watching for changes..." | Write-Host -ForegroundColor Cyan

        $Watcher.EnableRaisingEvents = $true
        $SourceId = "Sketch:$Sketch"

        $self = $MyInvocation.MyCommand
        $Params = [hashtable]$PSBoundParameters
        $Params.Remove("Watch")
        $ProjectRoot = $Script:ProjectRoot

        $Data = $self, $Params, $ProjectRoot
        $Action = {
            $self, $Params, $ProjectRoot = $event.MessageData

            $Change = $eventArgs.ChangeType
            $Path = [IO.Path]::GetRelativePath($ProjectRoot, $eventArgs.FullPath)

            "$Change`: $Path..." | Write-Host -ForegroundColor Cyan

            & $self @Params

            "...done. Watching for changes..." | Write-Host -ForegroundColor Cyan
        }

        $Subscriber = Register-ObjectEvent $Watcher Changed $Action -SourceIdentifier $SourceId -MessageData $Data

        try {
            while ($true) {sleep 1}

        } finally {
            $Subscriber | Unregister-Event
        }

    } finally {
        $Watcher.Dispose()
    }
}
#endregion sketches

#region convenience
Set-Alias deploy Deploy-ArduinoSketch

$CompleterSplats = (
    @{
        ParameterName = "Key"
        CommandName = "Get-ArduinoCliConfig", "Set-ArduinoCliConfig"
        ScriptBlock = {
            param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            (@($ConfigKeys) -like "$wordToComplete*"), (@($ConfigKeys) -like "*$wordToComplete*") | Write-Output
        }
    }, @{
        ParameterName = "Sketch"
        CommandName = "Resolve-ArduinoSketch", "Build-ArduinoSketch", "Push-ArduinoSketch", "Deploy-ArduinoSketch"
        ScriptBlock = {
            param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $Sketches = Find-ArduinoSketch
            (@($Sketches) -like "$wordToComplete*"), (@($Sketches) -like "*$wordToComplete*") | Write-Output
        }
    }, @{
        ParameterName = "Board"
        CommandName = "Build-ArduinoSketch", "Push-ArduinoSketch", "Deploy-ArduinoSketch"
        ScriptBlock = {
            param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $Boards = Get-ArduinoBoard
            (@($Boards) -like "$wordToComplete*"), (@($Boards) -like "*$wordToComplete*") | Write-Output
        }
    }, @{
        ParameterName = "Port"
        CommandName = "Connect-Arduino", "Build-ArduinoSketch", "Push-ArduinoSketch", "Deploy-ArduinoSketch"
        ScriptBlock = {
            param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $Ports = Get-ArduinoPort
            (@($Ports) -like "$wordToComplete*"), (@($Ports) -like "*$wordToComplete*") | Write-Output
        }
    }
)

$CompleterSplats | % {Register-ArgumentCompleter @_}

if ($null -eq $Global:PSDefaultParameterValues) {$Global:PSDefaultParameterValues = @{}}
$Global:PSDefaultParameterValues["*-ArduinoSketch:Board"] = {Get-ArduinoDefaultBoard}
#endregion convenience
