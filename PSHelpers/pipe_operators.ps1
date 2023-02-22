function split
{
    param
    (
        [Parameter(ValueFromPipeline)]
        [string[]]$InputObject,

        [Parameter(Mandatory, Position = 0, ValueFromRemainingArguments)]
        [ValidateCount(1, 3)]
        [string[]]$args
    )

    end
    {
        $input -split $args
    }
}

function join
{
    param
    (
        [Parameter(ValueFromPipeline)]
        [string[]]$InputObject,

        [Parameter(Mandatory, Position = 0, ValueFromRemainingArguments)]
        [ValidateCount(1, 3)]
        [AllowEmptyString()]
        [string[]]$args
    )

    end
    {
        $input -join $args
    }
}

function replace
{
    param
    (
        [Parameter(ValueFromPipeline)]
        [string[]]$InputObject,

        [Parameter(Mandatory, Position = 0)]
        [ValidateCount(1, 2)]
        [AllowEmptyString()]
        [string[]]$args
    )

    end
    {
        $input -replace $args
    }
}

function match
{
    param
    (
        [Parameter(ValueFromPipeline)]
        [string[]]$InputObject,

        [Parameter(Mandatory, Position = 0)]
        [string]$Pattern
    )

    end
    {
        $input -match $Pattern
    }
}

function notmatch
{
    param
    (
        [Parameter(ValueFromPipeline)]
        [string[]]$InputObject,

        [Parameter(Mandatory, Position = 0)]
        [string]$Pattern
    )

    end
    {
        $input -notmatch $Pattern
    }
}


function Switch-Order
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$InputObject
    )

    end
    {
        [Array]::Reverse($input)
        $input
    }
}
Set-Alias reverse Switch-Order


function Split-Line
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$InputObject,

        [switch]$SkipEmpty,

        [switch]$SkipEmptyOrWhitespace
    )

    process
    {
        $EolPattern = '\r?\n'
        $Lines = $InputObject -split $EolPattern

        if ($SkipWhitespace)
        {
            $Lines = $Lines | Where-Object {-not [string]::IsNullOrWhiteSpace($_)}
        }
        elseif ($SkipEmpty)
        {
            $Lines = $Lines | Where-Object {-not [string]::IsNullOrEmpty($_)}
        }

        $Lines | Write-Output
    }
}

function Trim-String
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$InputObject,

        [switch]$Stream
    )

    if ($MyInvocation.ExpectingInput)
    {
        $InputObject = $input
    }
    $InputObject | Out-String -Stream:$Stream | ForEach-Object {$_.Trim()}
}
Set-Alias trim Trim-String

function Split-Batch
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$InputObject,

        [Parameter(Mandatory, Position = 1)]
        [ValidateRange(2, 2147483647)]
        [int]$BatchSize
    )

    $Enumerator = $input.GetEnumerator()

    while ($true)
    {
        $Batch = 1..$BatchSize | ?{$Enumerator.MoveNext()} | %{$Enumerator.Current}
        if (-not $Batch) {break}

        $PSCmdlet.WriteObject($Batch)
    }
}
Set-Alias batch Split-Batch


function ConvertTo-ListExpression
{
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$InputObject,

        [Parameter(ParameterSetName = 'Default')]
        [switch]$Singleline,

        [Parameter(ParameterSetName = 'Default')]
        [switch]$DoubleQuote,

        [Parameter(ParameterSetName = 'Explicit')]
        [ValidatePattern("(?s)^(['`"]).*\1$")]      # First char is a quotemark, last char is same as first
        [string]$Join = "',$([Environment]::NewLine)'"
    )

    if ($MyInvocation.ExpectingInput)
    {
        $InputObject = $input
    }

    if ($DoubleQuote)
    {
        $Join = $Join -replace '(^.)|(.$)', '"'
    }

    if ($Singleline)
    {
        $Join = $Join -replace '\r?\n', ' '
    }

    $Quotemark = $Join[0]

    $Items = $InputObject | Split-Line -SkipEmptyOrWhitespace

    "$Quotemark$($Items -join $Join)$Quotemark"
}
