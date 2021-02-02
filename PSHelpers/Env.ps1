
$Global:IS_VSCODE = (
    (
        $PSVersionTable.PSVersion.Major -le 5 -and
        (Get-Process -Id (Get-CimInstance Win32_Process -Filter "ProcessId = $PID").ParentProcessId).ProcessName -eq 'Code'
    ) -or
    (
        $PSVersionTable.PSVersion.Major -ge 6 -and
        (Get-Process -Id $PId).Parent.CommandLine -match 'vscode'
    )
)
$Global:IS_ISE = $Host.Name -eq 'Windows PowerShell ISE Host'
$Global:IS_WSL = [bool]$env:WSL_DISTRO_NAME

$env:EDITOR = "code --wait"
