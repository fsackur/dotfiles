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
