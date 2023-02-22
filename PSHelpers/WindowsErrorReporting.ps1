function Disable-ProgramHasStoppedWorkingNotification
{
    param
    (
        [ValidatePattern('.exe$|.dll$|^\*$')]
        [string]$Name
    )

    if ($Name -and $Name -ne '*' -and [WildcardPattern]::ContainsWildcardCharacters($Name))
    {
        throw [System.Management.Automation.ParameterBindingException]::new("Parameter 'Name' does not support wildcards except for '*'.")
    }

    $Key = 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting\'
    if ($Name)
    {
        $null = New-ItemProperty (Join-Path $Key DebugApplications) -Name $Name -PropertyType Dword -Value 0
    }
    $null = New-ItemProperty $Key -Name DontShowUI -PropertyType Dword -Value 1
    $null = New-ItemProperty $Key -Name Disabled -PropertyType Dword -Value 1
    Set-Service WerSvc -StartupType Disabled
}

Register-ArgumentCompleter -CommandName Disable-ProgramHasStoppedWorkingNotification -ParameterName Name -ScriptBlock {
    param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    $Processes = Get-Process | Select-Object -ExpandProperty Path | Split-Path -Leaf | Sort-Object -Unique
    '*', ($Processes -like "$wordToComplete*"), ($Processes -like "*?$wordToComplete*") | Write-Output
}
