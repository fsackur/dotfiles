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

        [Parameter(Mandatory, Position = 0, ValueFromRemainingArguments)]
        [ValidateCount(1, 2)]
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
