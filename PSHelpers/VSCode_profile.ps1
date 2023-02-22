
if (-not $Global:PSDefaultParameterValues) {$Global:PSDefaultParameterValues = @{}}
$Global:PSDefaultParameterValues['Get-GitLog:Commits'] = 6

function Clear-VSCodeMonitorProcess
{
    $MonitorProcesses = Get-WmiObject Win32_Process -Filter "Caption LIKE '%Code%' AND CommandLine LIKE '%shutdownMonitorProcess%'"
    $MonitorProcesses | %{Get-Process -Id $_.ProcessId} | Stop-Process
}

if ($Global:IS_WSL)
{
    function Reset-VscodeWslInterop
    {
        <#
            .DESCRIPTION
            Fix 'UtilConnectToInteropServer:300: connect failed'
            https://github.com/microsoft/WSL/issues/5065
        #>
        param ([UInt32]$ProcessId = $PID)

        if (Test-Path /run/WSL/$ProcessId`_interop)
        {
            $env:WSL_INTEROP="/run/WSL/$ProcessId`_interop"
            return
        }

        Reset-VscodeWslInterop (Get-Process -Id $ProcessId).Parent.Id
    }
}
