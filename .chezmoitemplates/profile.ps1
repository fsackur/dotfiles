
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


# https://seeminglyscience.github.io/powershell/2017/09/30/invocation-operators-states-and-scopes
$GlobalState = [psmoduleinfo]::new($false)
$GlobalState.SessionState = $ExecutionContext.SessionState

$Job = Start-ThreadJob -Name TestJob -ArgumentList $GlobalState -ScriptBlock {
    $GlobalState = $args[0]
    . $GlobalState {
        # We always need to wait so that Get-Command itself is available
        do {Start-Sleep -Milliseconds 200} until (Get-Command Import-Module -ErrorAction Ignore)

        . "{{ .chezmoi.sourceDir }}/PSHelpers/Console.ps1"
        . "{{ .chezmoi.sourceDir }}/PSHelpers/git_helpers.ps1"
        . "{{ .chezmoi.sourceDir }}/PSHelpers/pipe_operators.ps1"
        . "{{ .chezmoi.sourceDir }}/PSHelpers/ModuleLoad.ps1"

        if (Test-Path "{{ .chezmoi.sourceDir }}/Work/work_profile.ps1")
        {
            . "{{ .chezmoi.sourceDir }}/Work/work_profile.ps1"
        }
    }
}

$null = Register-ObjectEvent -InputObject $Job -EventName StateChanged -MessageData ($globalState, $sb) -SourceIdentifier Job.Monitor -Action {
    # JobState: NotStarted = 0, Running = 1, Completed = 2, etc.
    if ($Event.SourceEventArgs.JobStateInfo.State -ge 2)
    {
        # propagate warnings and errors
        $Event.Sender | Receive-Job

        if ($Event.SourceEventArgs.JobStateInfo.State -eq 2)
        {
            $Event.Sender | Remove-Job
            Unregister-Event Job.Monitor
            Get-Job Job.Monitor | Remove-Job
        }
    }
}

Remove-Variable GlobalState
Remove-Variable Job
