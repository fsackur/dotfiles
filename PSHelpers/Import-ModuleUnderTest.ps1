function Import-ModuleUnderTest
{
    <#
        .SYNOPSIS
        Imports module from anywhere within the module's folder structure in PowerShell.

        .DESCRIPTION
        Imports the module that is currently being tested within the PowerShell session's directory location. The module under
        test will be imported so long as the PowerShell directory location is set to any location within the testing module's directory.

        .OUTPUTS
        [PSModuleInfo[]]

        .EXAMPLE
        Set-Location C:\Githubdata\Foobar
        Import-ModuleUnderTest

        ModuleType Version    Name                                ExportedCommands
        ---------- -------    ----                                ----------------
        Script     1.7.0.0    FooBar                              {Get-ModuleVersion, Get-TotalRam, Invoke-FooBar}

        Imports the module folder you run the command from, in this case the Foobar directory.

        .EXAMPLE
        Set-Location C:\Githubdata\Foobar\Private
        Import-ModuleUnderTest

        ModuleType Version    Name                                ExportedCommands
        ---------- -------    ----                                ----------------
        Script     1.7.0.0    FooBar                              {Get-ModuleVersion, Get-TotalRam, Invoke-FooBar}

        Will traverse the directory to the Module's root directory and imports the module located in the that directory.

    #>

    [CmdletBinding()]
    [OutputType([PSModuleInfo])]

    $ModuleBase = $PWD.Path

    while ($ModuleBase -NotMatch '^\w:(\\?)$')
    {
        $ModuleName = Split-Path -Path $ModuleBase -Leaf

        # Handle versioned module folders
        if ($ModuleName -Match '^\d+(\.\d+){2,3}$')
        {
            $ModuleName = Split-Path -Path (Split-Path -Path $ModuleBase) -Leaf
        }

        $Psd1Path = Join-Path -Path $ModuleBase -ChildPath "$ModuleName.psd1"

        if (Test-Path -Path $Psd1Path)
        {
            # Re-import module
            Import-Module -Name $Psd1Path -Force -DisableNameChecking -PassThru -Global
            return
        }

        $ModuleBase = Split-Path -Path $ModuleBase -Parent
    }

    Write-Warning "Not in a Powershell module directory, no module imported"
}
