$script:DockerContext = "scorpion"

$Hostname = hostname

if ($Hostname -eq $DockerContext) {
    $Script:DockerHost = $Hostname
    $script:IsLocal = $true
} else {
    $Context = docker context inspect $DockerContext | ConvertFrom-Json
    $Script:DockerHost = $Context.Endpoints.docker.Host -replace "^\w+://" -replace "\..*"
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
    Stop = "Stopping"
    Start = "Starting"
    Restart = "Restarting"
    Logs = "Showing logs for"
    Update = "Updating"
}

$script:Services = $null

$script:SshfsProcess = $null
function script:Mount-BasePath {
# function Mount-BasePath {
    if ($script:SshfsProcess) {
        return
    }

    if ($IsLocal -or (gci $BasePath -ea Ignore)) {
        return
    }

    sudo mkdir -p $BasePath
    sudo chmod 775 $BasePath
    sudo chown :$(id -g) $BasePath

    sudo sed -i "s/#\s*user_allow_other/user_allow_other/g" /etc/fuse.conf

    $MyModule = $MyInvocation.MyCommand.Module
    if ($MyModule) {
        $MyModule.OnRemove = {umount $BasePath}
    }

    sshfs -o allow_other $DockerHost`:$LocalBasePath $BasePath
}

function Get-Service
{
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline, Position = 0)]
        [SupportsWildcards()]
        [string]$Filter = "*"
    )

    if (-not $script:Services) {
        $Paths = if ($IsLocal) {
            Get-ChildItem $BasePath -Directory | Get-ChildItem -Filter "docker-compose.yml"
        } else {
            ssh @($DockerHost)[0] find $LocalBasePath -maxdepth 2 -name "docker-compose.yml"
        }

        $Paths = $Paths | Split-Path | Split-Path -Leaf | Sort-Object -Unique
        $script:Services = @($Paths) -notmatch "\.bak$"
    }

    $script:Services -like $Filter
}

function Invoke-ServiceScript
{
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
            $Name = $Name | Get-Service | Sort-Object -Unique
        }

        $CalledAs = (Get-PSCallStack)[0, 1] | % InvocationInfo | % InvocationName
        $CalledAs = @($CalledAs) -ne '&'
        $Verb = if ($CalledAs -eq "Show-ServiceLog") {"Logs"} else {$CalledAs -replace '-.*' | Select-Object -First 1}
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

    $Names = Get-Service
    (@($Names) -like "$wordToComplete*"), (@($Names) -like "*$wordToComplete*") | Write-Output
}

Set-Alias Stop-Service Invoke-ServiceScript
Set-Alias Start-Service Invoke-ServiceScript
Set-Alias Restart-Service Invoke-ServiceScript
Set-Alias Show-ServiceLog Invoke-ServiceScript
Set-Alias Update-Service Invoke-ServiceScript
Set-Alias stop Start-Service
Set-Alias start Start-Service
Set-Alias restart Start-Service
Set-Alias logs Show-ServiceLog
Set-Alias update Update-Service
