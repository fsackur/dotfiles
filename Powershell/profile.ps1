﻿
if (-not $PSDefaultParameterValues) {$Global:PSDefaultParameterValues = @{}}
$PSDefaultParameterValues += @{
    'Out-Default:OutVariable' = '+LastOutput'
}


if ($Host.Name -eq 'Visual Studio Code Host' -or (Get-Process -Id $PID).Parent.ProcessName -eq 'Code')
{
    $env:EDITOR = "code --wait"
}
else
{
    Set-Location C:\Githubdata -ErrorAction SilentlyContinue
    $env:EDITOR = "'$env:LOCALAPPDATA\Notepad++\notepad++.exe' -multiInst -nosession"
}

if ($Host.Name -eq 'Windows PowerShell ISE Host')
{
    Remove-Item Alias:\ise -Force
    function ise
    {
        param ($Files)

        $Files | %{$psISE.CurrentPowerShellTab.Files.Add((Resolve-Path $_))} | Out-Null
    }
}
else
{
    function global:prompt {
        $realLASTEXITCODE = $LASTEXITCODE

        Write-Host($pwd.ProviderPath) -nonewline

        Write-VcsStatus

        $global:LASTEXITCODE = $realLASTEXITCODE
        return "`n> "
    }

    Import-Module Posh-Git

    $GitPromptSettings | Add-Member NoteProperty -Name 'DefaultPromptSuffix' -Value '`n$(''>'' * ($nestedPromptLevel + 1)) ' -ErrorAction SilentlyContinue
}


Remove-Item Alias:curl -ErrorAction SilentlyContinue

function Clear-VSCodeMonitorProcess
{
    $MonitorProcesses = Get-WmiObject Win32_Process -Filter "Caption LIKE '%Code%' AND CommandLine LIKE '%shutdownMonitorProcess%'"
    $MonitorProcesses | %{Get-Process -Id $_.ProcessId} | Stop-Process
}


function Git-Add
{
    [CmdletBinding()]
    param ()
    git add *; git status -v; git status
}
Set-Alias a Git-Add

function Git-Commit
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Message
    )
    git commit -m $Message
}
Set-Alias c Git-Commit

function Git-Branch
{
    param
    (
        [Parameter(Mandatory, Position=0)]
        [ValidateNotNullOrEmpty()]
        [string]$Branch
    )

    $chbr = git checkout $Branch *>&1

    if ($chbr.ToString() -match 'did not match any file')
    {
        Write-Host -ForegroundColor DarkYellow 'Creating new branch...'
        $newbr = git checkout -b $Branch *>&1
        $pushbr = git push -u origin $Branch *>&1
        if (-not ($pushbr | Out-String) -match 'set up to track remote branch')
        {
            $pushbr
        }
    }
}
Set-Alias b Git-Branch

function Git-Checkout
{
    param
    (
        [Parameter(Mandatory, Position = 0)]
        [string]$Branch
    )

    git checkout $Branch
    git checkout -b ($Branch -replace '^.*/')
    git branch -u $Branch
}
Register-ArgumentCompleter -CommandName Git-Checkout -ParameterName Branch -ScriptBlock {
    param
    (
        $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters
    )

    (git branch -a) -match '^  remotes/' -replace '^  remotes/' -like "$wordToComplete*"
}
Set-Alias gco Git-Checkout

function Clear-DeletedRemoteBranches
{
    (git branch -vv |sls ': gone') -replace '^ *' -replace ' .*' | %{git branch -D $_}
}

function Elevate
{
    param ($Username, $Password)

    $Cred = [pscredential]::new($Username, ($Password | ConvertTo-SecureString -AsPlainText -Force))

    Start-Process powershell -Credential $Cred -NoNewWindow -ArgumentList "Start-Process cmd -Verb RunAs"
}
