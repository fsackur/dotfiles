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
