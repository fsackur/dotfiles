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


function Clear-Modules
{
    $ModuleToKeepPatterns = (
        'Microsoft\.PowerShell',
        'CimCmdlets',
        'PowerShellEditorServices',
        'PSReadline',
        'oh-my-posh',
        'posh-git',
        'Plugz',
        'Configuration',
        'Metadata'
    )
    $Pattern = $ModuleToKeepPatterns -join '|'
    gmo | ? Name -NotMatch $Pattern | rmo -Force
}


function Import-GitModule
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [string]$GitRepoRoot,

        [switch]$Global,

        [ValidateNotNull()]
        [string]$Prefix,

        [Parameter(ParameterSetName = 'Name', Mandatory, Position = 0, ValueFromPipeline)]
        [Parameter(ParameterSetName = 'Branch', Mandatory, Position = 0, ValueFromPipeline)]
        [string[]]$Name,

        [Parameter(ParameterSetName = 'FullyQualifiedName', Mandatory, Position = 0, ValueFromPipeline)]
        [Microsoft.PowerShell.Commands.ModuleSpecification[]]$FullyQualifiedName,

        [ValidateNotNull()]
        [string[]]$Function,

        [ValidateNotNull()]
        [string[]]$Cmdlet,

        [ValidateNotNull()]
        [string[]]$Variable,

        [ValidateNotNull()]
        [string[]]$Alias,

        [switch]$Force,

        [switch]$PassThru,

        [switch]$AsCustomObject,

        [Parameter(ParameterSetName = 'Name')]
        [Alias('Version')]
        [version]$MinimumVersion,

        [Parameter(ParameterSetName = 'Name')]
        [string]$MaximumVersion,

        [Parameter(ParameterSetName = 'Name')]
        [version]$RequiredVersion,

        [Parameter(ParameterSetName = 'Branch')]
        [Alias('Branch')]
        [Alias('Tag')]
        [string]$Ref,

        [Alias('Args')]
        [System.Object[]]$ArgumentList,

        [switch]$DisableNameChecking,

        [Alias('NoOverwrite')]
        [switch]$NoClobber,

        [ValidateSet('Local','Global')]
        [string]$Scope
    )

    begin
    {
        #TODO: xplat
        $TempFolder = Join-Path $env:TEMP TempModules
        $null       = New-Item $TempFolder -ItemType Directory -Force -ErrorAction Stop
    }

    end
    {
        if (-not $MyInvocation.ExpectingInput)
        {
            if ($FullyQualifiedName)
            {
                $input = $FullyQualifiedName
            }
            else
            {
                $input = $Name
            }
        }

        foreach ($Item in $input)
        {
            Remove-Variable Name

            if ($FullyQualifiedName)
            {
                $ModuleSpec = $Item
                $Name            = $ModuleSpec.Name
                $MinimumVersion  = $ModuleSpec.Version
                $MaximumVersion  = $ModuleSpec.MaximumVersion
                $RequiredVersion = $ModuleSpec.RequiredVersion
            }
            else
            {
                $Name = $Item
            }


            $Repo   = Join-Path $GitRepoRoot $Name
            $GitDir = Join-Path $Repo .git


            $NotFoundMessage = "No valid version of module '$Name' was found in git history in '$Repo'."

            if ($RequiredVersion)
            {
                $SelectedVersion = $RequiredVersion
                $Ref = "v$SelectedVersion"

                $GitOutput = git --git-dir=$GitDir name-rev --tags $Ref --name-only
                if ($GitOutput -ne $Ref)
                {
                    Write-Error $NotFoundMessage
                    continue
                }
            }
            elseif (-not $Ref)
            {
                $Tags = git --git-dir=$GitDir tag --list 'v*'

                [version[]]$AvailableVersions = @($Tags) -match '^v(\d+\.){2,3}\d+$' -replace '^v'
                $AvailableVersions = $AvailableVersions | Sort-Object -Descending

                $SelectedVersion = $AvailableVersions |
                    Where-Object {
                        ((-not $MinimumVersion) -or ($_ -ge $MinimumVersion)) -and
                        ((-not $MaximumVersion) -or ($_ -le $MaximumVersion))
                    } |
                    Select-Object -First 1

                if (-not $SelectedVersion)
                {
                    Write-Error $NotFoundMessage
                    continue
                }

                $Ref = "v$SelectedVersion"
            }


            $OutputPath = $TempFolder |
                Join-Path -ChildPath $Name |
                Join-Path -ChildPath $SelectedVersion

            Remove-Item $OutputPath -Recurse -Force -ErrorAction SilentlyContinue
            $null = New-Item $OutputPath -ItemType Directory -Force -ErrorAction Stop


            # Clones with --shared have hardlinks to the source; can break if you, e.g., delete
            # branches in the source
            $GitOutput = git clone --shared --branch $Ref $Repo $OutputPath *>&1
            if ($LASTEXITCODE)
            {
                Write-Error $GitOutput
                continue
            }

            $Psd1Path = Join-Path $OutputPath "$Name.psd1"

            $Params = [hashtable]$PSBoundParameters
            $null = (
                'GitRepoRoot',
                'Name',
                'FullyQualifiedName',
                'MinimumVersion',
                'RequiredVersion',
                'MaximumVersion'
            ) | ForEach-Object {$Params.Remove($_)}

            $Psd1Path | Import-Module @Params
        }
    }
}
