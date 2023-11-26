
$OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = [Text.Encoding]::UTF8
$Global:PSDefaultParameterValues['*:Encoding'] = $Global:PSDefaultParameterValues['*:InputEncoding'] = $Global:PSDefaultParameterValues['*:OutputEncoding'] = $OutputEncoding

if ($PSVersionTable.PSEdition -ne 'Core')
{
    Set-Variable IsWindows -Value $true -Option Constant -Scope Global
    Set-Variable IsLinux -Value $false -Option Constant -Scope Global
    Set-Variable IsMacOS -Value $false -Option Constant -Scope Global
    Set-Variable IsCoreCLR -Value $false -Option Constant -Scope Global
}

#region PWD
function Test-VSCode
{
    if ($null -eq $Global:IsVSCode)
    {
        if ($env:TERM -ne 'xterm-256color')  # May not always be this value in Code, but it's definitely not in kitty
        {
            $Global:IsVSCode = $false
        }
        elseif ($env:TERM_PROGRAM)
        {
            $Global:IsVSCode = $env:TERM_PROGRAM -eq 'vscode'
        }
        else
        {
            $Process = Get-Process -Id $PID
            do
            {
                $Global:IsVSCode = $Process.ProcessName -match '^node|(Code( - Insiders)?)|winpty-agent$'
                $Process = $Process.Parent
            }
            while ($Process -and -not $Global:IsVSCode)
        }
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
#endregion PWD

if (Get-Command starship -ErrorAction SilentlyContinue)
{
    # brew install starship / choco install starship / winget install Starship.Starship
    $env:STARSHIP_CONFIG = $PSScriptRoot | Split-Path | Join-Path -ChildPath starship.toml
    starship init powershell --print-full-init | Out-String | Invoke-Expression
}


$LogDeferredLoad = $false
function Write-DeferredLoadLog
{
    param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Message
    )

    if (-not $LogDeferredLoad) {return}

    $LogPath = if ($env:XDG_CACHE_HOME)
    {
        Join-Path $env:XDG_CACHE_HOME PowerShellDeferredLoad.log
    }
    else
    {
        Join-Path $HOME .cache/PowerShellDeferredLoad.log
    }

    $Now = [datetime]::Now
    if (-not $Start)
    {
        $Global:Start = $Now
    }

    $Timestamp = $Now.ToString('o')
    (
        $Timestamp,
        ($Now - $Start).ToString('ss\.fff'),
        [System.Environment]::CurrentManagedThreadId.ToString().PadLeft(3, ' '),
        $Message
    ) -join '  ' | Out-File -FilePath $LogPath -Append
}


$LogDeferredLoad = $false
"=== Starting deferred load ===" | Write-DeferredLoadLog

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


# https://seeminglyscience.github.io/powershell/2017/09/30/invocation-operators-states-and-scopes
$GlobalState = [psmoduleinfo]::new($false)
$GlobalState.SessionState = $ExecutionContext.SessionState

# A runspace to run our code asynchronously; pass in $Host to support Write-Host
$Runspace = [runspacefactory]::CreateRunspace($Host)
$Powershell = [powershell]::Create($Runspace)
$Runspace.Open()
$Runspace.SessionStateProxy.PSVariable.Set('GlobalState', $GlobalState)

# ArgumentCompleters are set on the ExecutionContext, not the SessionState
# Note that $ExecutionContext is not an ExecutionContext, it's an EngineIntrinsics
$Private = [System.Reflection.BindingFlags]'Instance, NonPublic'
$ContextField = [System.Management.Automation.EngineIntrinsics].GetField('_context', $Private)
$GlobalContext = $ContextField.GetValue($ExecutionContext)

# Get the ArgumentCompleters. If null, initialise them.
$ContextCACProperty = $GlobalContext.GetType().GetProperty('CustomArgumentCompleters', $Private)
$ContextNACProperty = $GlobalContext.GetType().GetProperty('NativeArgumentCompleters', $Private)
$CAC = $ContextCACProperty.GetValue($GlobalContext)
$NAC = $ContextNACProperty.GetValue($GlobalContext)
if ($null -eq $CAC)
{
    $CAC = [System.Collections.Generic.Dictionary[string, scriptblock]]::new()
    $ContextCACProperty.SetValue($GlobalContext, $CAC)
}
if ($null -eq $NAC)
{
    $NAC = [System.Collections.Generic.Dictionary[string, scriptblock]]::new()
    $ContextNACProperty.SetValue($GlobalContext, $NAC)
}

# Get the AutomationEngine and ExecutionContext of the runspace
$RSEngineField = $Runspace.GetType().GetField('_engine', $Private)
$RSEngine = $RSEngineField.GetValue($Runspace)
$EngineContextField = $RSEngine.GetType().GetFields($Private) | Where-Object {$_.FieldType.Name -eq 'ExecutionContext'}
$RSContext = $EngineContextField.GetValue($RSEngine)

# Set the runspace to use the global ArgumentCompleters
$ContextCACProperty.SetValue($RSContext, $CAC)
$ContextNACProperty.SetValue($RSContext, $NAC)

Remove-Variable -ErrorAction Ignore (
    'Private',
    'GlobalContext',
    'ContextField',
    'ContextCACProperty',
    'ContextNACProperty',
    'CAC',
    'NAC',
    'RSEngineField',
    'RSEngine',
    'EngineContextField',
    'RSContext',
    'Runspace'
)

$Wrapper = {
    # Without a sleep, you get issues:
    #   - occasional crashes
    #   - prompt not rendered
    #   - no highlighting
    # Assumption: this is related to PSReadLine.
    # 20ms seems to be enough on my machine, but let's be generous - this is non-blocking
    Start-Sleep -Milliseconds 200

    . $GlobalState {. $Deferred; Remove-Variable Deferred}
}

$AsyncResult = $Powershell.AddScript($Wrapper.ToString()).BeginInvoke()

$null = Register-ObjectEvent -MessageData $AsyncResult -InputObject $Powershell -EventName InvocationStateChanged -SourceIdentifier __DeferredLoaderCleanup -Action {
    $AsyncResult = $Event.MessageData
    $Powershell = $Event.Sender
    if ($Powershell.InvocationStateInfo.State -ge 2)
    {
        if ($Powershell.Streams.Error)
        {
            $Powershell.Streams.Error | Out-String | Write-Host -ForegroundColor Red
        }

        try
        {
            # Profiles swallow output; it would be weird to output anything here
            $null = $Powershell.EndInvoke($AsyncResult)
        }
        catch
        {
            $_ | Out-String | Write-Host -ForegroundColor Red
        }

        $h1 = Get-History -Id 1 -ErrorAction Ignore
        if ($h1.CommandLine -match '\bcode\b.*shellIntegration\.ps1')
        {
            $Msg = 'VS Code Shell Integration is enabled. This may cause issues with deferred load. To disable it, set "terminal.integrated.shellIntegration.enabled" to "false" in your settings.'
            Write-Host $Msg -ForegroundColor Yellow
        }

        $PowerShell.Dispose()
        $Runspace.Dispose()
        Unregister-Event __DeferredLoaderCleanup
        Get-Job __DeferredLoaderCleanup | Remove-Job
    }
}

Remove-Variable Wrapper, Powershell, AsyncResult, GlobalState

"synchronous load complete" | Write-DeferredLoadLog
