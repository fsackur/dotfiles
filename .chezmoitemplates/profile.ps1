
$OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = [Text.Encoding]::UTF8

function Test-VSCode
{
    if ($null -eq $Global:IsVSCode)
    {
        $Process = Get-Process -Id $PID
        do
        {
            $Global:IsVSCode = $Process.ProcessName -match '^node|(Code( - Insiders)?)|winpty-agent$'
            $Process = $Process.Parent
        }
        while ($Process -and -not $Global:IsVSCode)
    }
    return $Global:IsVSCode
}

if (Test-VSCode)
{}
elseif (Test-Path /gitroot)
{
    Set-Location /gitroot
}
elseif (Test-Path ~/gitroot)
{
    Set-Location ~/gitroot
}

if (Get-Command starship -ErrorAction SilentlyContinue)
{
    # brew install starship / choco install starship / winget install Starship.Starship
    $env:STARSHIP_CONFIG = $PSScriptRoot | Split-Path | Join-Path -ChildPath starship.toml
    starship init powershell --print-full-init | Out-String | Invoke-Expression
}

function Write-DeferredLoadLog
{
    param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Message
    )

    $Now = [datetime]::Now
    if (-not $Start)
    {
        $Global:Start = $Now
    }

    $LogPath = if ($env:XDG_CACHE_HOME)
    {
        Join-Path $env:XDG_CACHE_HOME PowerShellDeferredLoad.log
    }
    else
    {
        Join-Path $HOME .cache/PowerShellDeferredLoad.log
    }

    $Timestamp = $Now.ToString('o')
    (
        $Timestamp,
        ($Now - $Start).ToString('ss\.ffffff'),
        [System.Environment]::CurrentManagedThreadId.ToString().PadLeft(3, ' '),
        $Message
    ) -join '  ' | Out-File -FilePath $LogPath -Append
}
"=== Starting deferred load ===" | Write-DeferredLoadLog

# https://seeminglyscience.github.io/powershell/2017/09/30/invocation-operators-states-and-scopes
$GlobalState = [psmoduleinfo]::new($false)
$GlobalState.SessionState = $ExecutionContext.SessionState

$Deferred = {
    "dot-sourcing script" | Write-DeferredLoadLog

    . "{{ .chezmoi.sourceDir }}/PSHelpers/Console.ps1"
    . "{{ .chezmoi.sourceDir }}/PSHelpers/git_helpers.ps1"
    . "{{ .chezmoi.sourceDir }}/PSHelpers/pipe_operators.ps1"
    . "{{ .chezmoi.sourceDir }}/PSHelpers/ModuleLoad.ps1"

    if (Test-Path "{{ .chezmoi.sourceDir }}/Work/work_profile.ps1")
    {
        . "{{ .chezmoi.sourceDir }}/Work/work_profile.ps1"
    }

    "completed dot-sourcing script" | Write-DeferredLoadLog
}

$Job = Start-ThreadJob -Name TestJob -ArgumentList $GlobalState, $Deferred -ScriptBlock {
    $GlobalState = $args[0]
    $Deferred = $args[1]

    . $GlobalState {
        # We always need to wait so that Get-Command itself is available
        do {Start-Sleep -Milliseconds 200} until (Get-Command Import-Module -ErrorAction Ignore)
    }

    . $GlobalState $Deferred

    # ArgumentCompleters are added to the ExecutionContext object (not $ExecutionContext), not the SessionState object
    # Since this job has a different context, argument completers don't work
    # Workaround; re-run the deferred load in the event handler, which uses the correct context
    # This is still an improvement, because we've warmed up the script cache
    # However... code will be run twice in the global state, which could be undesirable...
    . $GlobalState {$Callback = $args[0]} $Deferred
}

# Invoke callback code and clean up
$null = Register-ObjectEvent -InputObject $Job -MessageData $GlobalState -EventName StateChanged -SourceIdentifier Job.Monitor -Action {
    # JobState: NotStarted = 0, Running = 1, Completed = 2, etc.
    if ($Event.SourceEventArgs.JobStateInfo.State -ge 2)
    {
        "receiving deferred load job: $($Event.SourceEventArgs.JobStateInfo.State)" | Write-DeferredLoadLog

        # propagate warnings and errors
        $Event.Sender | Receive-Job

        if ($Event.SourceEventArgs.JobStateInfo.State -eq 2)
        {
            # if $Callback is defined, run it in the interactive ExecutionContext
            if ($Callback -is [scriptblock])
            {
                "starting deferred callback" | Write-DeferredLoadLog
                . $Callback
                "completed deferred callback" | Write-DeferredLoadLog
            }

            $Event.Sender | Remove-Job
            Unregister-Event Job.Monitor
            Get-Job Job.Monitor | Remove-Job

            "cleaned up deferred load job" | Write-DeferredLoadLog
        }
    }
}

Remove-Variable GlobalState, Job, Callback -ErrorAction Ignore
"synchronous load complete" | Write-DeferredLoadLog
