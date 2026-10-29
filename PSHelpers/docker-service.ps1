$script:DockerContext = "scorpion"

$Hostname = $(hostname) -replace "\..*"

if ($Hostname -eq $DockerContext) {
    $Script:DockerHost = $Hostname
    $script:IsLocal = $true
} else {
    $Context = docker context inspect $DockerContext | ConvertFrom-Json
    $Script:DockerHost = $Context.Endpoints.docker.Host -replace "^\w+://" -replace "\..*" | Select-Object -First 1
    $script:IsLocal = $DockerHost -eq $Hostname
}

$script:LocalBasePath = "/services"
$script:BasePath = if ($IsLocal) {
    $LocalBasePath
} else {
    "/$DockerHost"
}

$script:DArgs = if ($IsLocal) {@()} else {"--context", $DockerContext}
$script:Actions = @{
    Status = {
        docker @DArgs compose ps -a --format json | ConvertFrom-Json | % {
            $_.CreatedAt = [datetime]($_.CreatedAt -replace " \D+$")
            $_.PSTypeNames.Insert(0, "DockerProcess")
            $_
        }
    }
    Stop = {
        docker @DArgs compose down --remove-orphans @args
    }
    Start = {
        docker @DArgs compose up --remove-orphans --detach @args
    }
    Restart = {
        docker @DArgs compose down --remove-orphans
        docker @DArgs compose up --remove-orphans --detach @args
    }
    Logs = {
        docker @DArgs compose logs @args
    }
    Update = {
        docker @DArgs compose pull
        docker @DArgs compose build
    }
}
$script:Participles = @{
    Status = "Showing"
    Stop = "Stopping"
    Start = "Starting"
    Restart = "Restarting"
    Logs = "Showing logs for"
    Update = "Updating"
}

$script:Services = $null

function script:Mount-BasePath {
    if ($IsLocal) {return}

    $Target = "$DockerHost`:$LocalBasePath"
    $Mountpoint = $BasePath

    $MyModule = $MyInvocation.MyCommand.Module
    if ($MyModule) {
        $Cleanup = {
            if ((mount) -match "$Target on $BasePath ") {
                umount $BasePath
            }
        }
        $MyModule.OnRemove = $Cleanup
    }

    if (gci $BasePath -ea Ignore) {return}

    sudo mkdir -p $BasePath
    sudo chmod 775 $BasePath
    sudo chown :$(id -g) $BasePath

    sudo sed -i "s/#\s*user_allow_other/user_allow_other/g" /etc/fuse.conf


    sshfs -o allow_other $Target $Mountpoint
}

function script:Get-ServiceName {
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline, Position = 0)]
        [SupportsWildcards()]
        [string]$Name = "*"
    )

    if (-not $script:Services) {
        $Paths = if ($IsLocal) {
            Get-ChildItem $BasePath -Directory | Get-ChildItem -Filter "docker-compose.yml"
        } else {
            ssh $DockerHost find $LocalBasePath -maxdepth 2 -name "docker-compose.yml"
        }

        $Paths = $Paths | Split-Path | Split-Path -Leaf | Sort-Object -Unique
        $script:Services = @($Paths) -notmatch "\.bak$"
    }

    $script:Services -like $Name
}

function Get-Service {
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline, Position = 0)]
        [SupportsWildcards()]
        [string[]]$Name = "*"
    )

    Invoke-ServiceScript $Name
}

function Invoke-ServiceScript {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [SupportsWildcards()]
        [string[]]$Name,

        [Parameter()]
        [scriptblock]$Action,

        [Parameter(ValueFromRemainingArguments)]
        [string[]]$ExtraArgs
    )

    begin
    {
        if ($Name)
        {
            $Name = $Name | Get-ServiceName | Sort-Object -Unique
            $Name | & $MyInvocation.MyCommand
            break
        }

        $CalledAs = (Get-PSCallStack)[0, 1, 2] | % InvocationInfo | % InvocationName
        $CalledAs = @($CalledAs) -ne '&' -ne $MyInvocation.MyCommand.Name

        $Verb = if ($CalledAs -match "log") {
            "Logs"
        } elseif ($CalledAs -eq "Get-Service" -or $CalledAs -eq "status") {
            "Status"
        } else {
            $CalledAs -replace '-.*' | Select-Object -First 1
        }

        if (-not $Action)
        {
            $Action = $Actions[$Verb]
        }
    }

    process
    {
        [string]$Name = $Name
        Write-Verbose "$($Participles[$Verb]) $Name"

        $Path = Join-Path $BasePath $Name
        if (-not (Test-Path $Path)) {
            Mount-BasePath
        }

        Push-Location $Path -ErrorAction Stop
        try
        {
            & $Action @ExtraArgs
        }
        finally
        {
            Pop-Location
        }
    }
}

Register-ArgumentCompleter -CommandName Invoke-ServiceScript -ParameterName Name -ScriptBlock {
    param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    $Names = Get-ServiceName
    (@($Names) -like "$wordToComplete*"), (@($Names) -like "*$wordToComplete*") | Write-Output
}

Set-Alias Stop-Service Invoke-ServiceScript
Set-Alias Start-Service Invoke-ServiceScript
Set-Alias Restart-Service Invoke-ServiceScript
Set-Alias Show-ServiceLog Invoke-ServiceScript
Set-Alias Update-Service Invoke-ServiceScript
Set-Alias status Get-Service
Set-Alias stop Stop-Service
Set-Alias start Start-Service
Set-Alias restart Restart-Service
Set-Alias logs Show-ServiceLog
Set-Alias update Update-Service
