$script:DockerContext = "scorpion"

$script:Services = $null
$script:BasePath = "/services/"

$script:IsLocal = if ($(hostname) -eq $DockerContext) {
    $true
} else {
    $Context = docker context inspect $DockerContext | ConvertFrom-Json
    $Hostname = $Context.Endpoints.docker.Host -replace "^\w+://" -replace "\..*"
    $Hostname -eq $(hostname)
}

$script:DArgs = if ($IsLocal) {@()} else {"--context", $DockerContext}
$script:Actions = @{
    Stop = {
        docker @DArgs compose down --remove-orphans
    }
    Start = {
        docker @DArgs compose up --remove-orphans --detach
    }
    Restart = {
        docker @DArgs compose down --remove-orphans
        docker @DArgs compose up --remove-orphans --detach
    }
    Logs = {
        docker @DArgs compose logs
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
            ssh @($Hostname)[0] find $BasePath -maxdepth 2 -name "docker-compose.yml"


        }
        $script:Services = @($Paths) -notmatch "\.bak$" | Split-Path | Split-Path -Leaf
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
            $Name | & $MyInvocation.MyCommand
            break
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

        Join-Path $BasePath $Name | Push-Location -ErrorAction Stop
        try
        {
            & $Action $ExtraArgs
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
