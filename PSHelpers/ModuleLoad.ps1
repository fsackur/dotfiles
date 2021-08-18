function Export-PrivateModuleMember
{
    <#
        .SYNOPSIS
        Exports non-exported functions from a module.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param
    (
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [string]$Module,

        [switch]$ExportVariables
    )

    process
    {
        [psmoduleinfo]$Module = Get-Module $Module -ErrorAction Stop | Select-Object -First 1
        $Scriptblock = {
            param
            (
                [psmoduleinfo]$Module,
                [switch]$ExportVariables
            )

            $Commands = Get-Command -Module $Module
            $ExportTable = $Module.ExportedCommands
            $PrivateCommands = $Commands | Where-Object {-not $ExportTable.ContainsKey($_.Name)}

            foreach ($Command in $PrivateCommands)
            {
                Write-Verbose "Exporting private function '$($Command.Name)'"
                Set-Content function:\Global:$($Command.Name) $Command.ScriptBlock
            }

            if ($ExportVariables)
            {
                $Variables = Get-Variable -Scope 1
                $GlobalVariableLookup = Get-Variable -Scope 2 | Group-Object Name -AsHashTable
                $ModuleVariables = $Variables |
                    Where-Object {-not $GlobalVariableLookup.ContainsKey($_.Name)}

                foreach ($Variable in $ModuleVariables)
                {
                    Write-Verbose "Exporting private variable '$($Variable.Name)'"
                    Set-Variable -Name $Variable.Name -Value $Variable.Value -Scope 2
                }
            }

        }

        <#
            The call operator, &, can run a scriptblock within the scope of a module:
                & (Get-Module Foo) {Do-Stuff}
            The above works even if Do-Stuff is a private function in Foo.
        #>
        & $Module $Scriptblock -Module $Module -ExportVariables $ExportVariables
    }
}


$ArgumentCompleterSplat = @{
    CommandName   = 'Export-PrivateModuleMember'
    ParameterName = 'Module'
    ScriptBlock   = {
        param
        (
            $commandName,
            $parameterName,
            $wordToComplete,
            $commandAst,
            $fakeBoundParameters
        )

        Get-Module |
            Select-Object -ExpandProperty Name |
            Sort-Object -Unique |
            Where-Object {$_ -like "$wordToComplete*"}
    }
}
Register-ArgumentCompleter @ArgumentCompleterSplat



function Reload-Module
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
    param
    (
        [switch]$ExportAll
    )

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
            if ($ExportAll)
            {
                Export-PrivateModuleMember $ModuleName -ExportVariables
            }
            return
        }

        $ModuleBase = Split-Path -Path $ModuleBase -Parent
    }

    Write-Warning "Not in a Powershell module directory, no module imported"
}
