function Switch-Dictionary
{
    <#
        .SYNOPSIS
        Create a dictionary with the keys and values swapped.
    #>

    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [Collections.IDictionary]$InputObject
    )

    process
    {
        $Type = $InputObject.GetType()
        if ($Type.IsGenericType)
        {
            $TypeArgs = $Type.GenericTypeArguments
            $TypeArgs = $TypeArgs[1, 0]

            $GenericType = $Type.GetGenericTypeDefinition()
            $Type = $GenericType.MakeGenericType($TypeArgs)
        }

        $Output = $Type::new()

        $InputObject.GetEnumerator() | ForEach-Object {$Output.Add($_.Value, $_.Key)}

        $Output
    }
}


function New-ElevatedShell
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, Position = 0)]
        [pscredential]
        [Management.Automation.Credential()]$Credential
    )

    $Shell = if ($PSVersionTable.PSVersion.Major -le 5) {'powershell'} else {'pwsh'}
    Start-Process $Shell -Credential $Credential -NoNewWindow -ArgumentList (
        "-NoProfile",
        "-NoLogo",
        "-WindowStyle", "Hidden",
        "-Command", "Start-Process $Shell -Verb RunAs -ArgumentList '-NoExit'"
    )
}
Set-Alias elevate New-ElevatedShell

function ConvertTo-Plaintext
{
    <#
        .SYNOPSIS
        Converts a SecureString to a plaintext string.

        .DESCRIPTION
        Converts a SecureString to a plaintext string.

        .PARAMETER SecureString
        The SecureString to convert to plaintext.

        .INPUTS
        [securestring]

        .OUTPUTS
        [string]

        .EXAMPLE
        $Password = ConvertTo-SecureString 'hunter2' -AsPlainText -Force
        ConvertTo-Plaintext -SecureString $Password

        Converts the string 'hunter2' into a SecureString, then back to plaintext.
    #>

    [OutputType([string])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, Position = 0)]
        [Alias("SecurePassword")]
        [System.Security.SecureString]$SecureString
    )

    process
    {
        # This approach copied from Utils.cs in Microsoft.PowerShell.SecretStore
        try
        {
            $Pointer = [Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($SecureString)
            $Bytes = [Byte[]]::new($SecureString.Length * 2)
            [Runtime.InteropServices.Marshal]::Copy($Pointer, $Bytes, 0, $Bytes.Length)
            [Text.Encoding]::Unicode.GetString($Bytes)
        }
        finally
        {
            # This is important, it zeroes out the memory
            [Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($Pointer)
        }
    }
}

function Copy-Object
{
    <#
        .SYNOPSIS
        Performs a deep copy of an object.

        All properties and methods are preserved.
    #>

    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [object]$InputObject
    )

    begin
    {
        $Formatter = [Runtime.Serialization.Formatters.Binary.BinaryFormatter]::new()
    }

    process
    {
        $Stream = [IO.MemoryStream]::new()
        $Formatter.Serialize($Stream, $InputObject)
        $Stream.Position = 0
        $Formatter.Deserialize($Stream)
    }
}

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
            $PrivateCommands = $Commands | Where-Object {$_.Scriptblock -and -not $ExportTable.ContainsKey($_.Name)}

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


function ConvertTo-Sentence
{
    <#
        .SYNOPSIS
        Breaks a PS command name into words.
    #>
    [OutputType([string[]])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [string]$InputObject,

        [switch]$CapitaliseFirstWord
    )

    process
    {
        # split on dash or before upper-case letter that isn't followed by another upper-case
        $Words = $InputObject -csplit '-|(?<=\w)(?=[A-Z][^A-Z])'

        # Don't lower-case capitalised acronyms
        $ContainsLowercasePattern = [regex]'.*[a-z].*'
        $Words = $Words | ForEach-Object {
            $ContainsLowercasePattern.Replace($_, {$args[0].Value.ToLower()})
        }

        $TextInfo = (Get-Culture).TextInfo
        if ($CapitaliseFirstWord)
        {
            $Words[0] = $TextInfo.ToTitleCase($Words[0])
        }

        $PSCmdlet.WriteObject($Words)
    }
}
