$script:BasePath = '/services/'
$script:Actions = @{
    Stop = {
        docker compose down --remove-orphans
    }
    Start = {
        docker compose up --remove-orphans --detach
    }
    Restart = {
        docker compose down --remove-orphans
        docker compose up --remove-orphans --detach
    }
    Logs = {
        docker compose logs
    }
    Update = {
        docker compose pull
        docker compose build
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
        [string]$Filter = '*'
    )

    Get-ChildItem $BasePath -Directory -Filter $Filter |
        Get-ChildItem -Filter 'docker-compose.yml' |
        Split-Path |
        Split-Path -Leaf
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
