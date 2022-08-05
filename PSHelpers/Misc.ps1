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
