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
        & $Module {
            $Module = $args[0]
            $ExportVariables = $args[1]

            $Commands = Get-Command -Module $Module
            $ExportTable = $Module.ExportedCommands
            $PrivateCommands = $Commands | Where-Object {-not $ExportTable.ContainsKey($_.Name)}

            foreach ($Command in $PrivateCommands)
            {
                Write-Verbose "Exporting private function '$($Command.Name)'"
                Set-Content function:\Global:$($Command.Name) $Command.ScriptBlock # $Module.NewBoundScriptBlock([scriptblock]::Create($Command.Definition))
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

        } $Module $ExportVariables
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