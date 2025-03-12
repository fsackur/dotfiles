if (-not (Get-Command ip -CommandType Application -ErrorAction Ignore))
{
    return
}

function Get-NetInterfaceName
{
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [SupportsWildcards()]
        [ArgumentCompleter({
            param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $Names = Get-NetInterfaceName
            ($Names -like "$wordToComplete*"), ($Names -like "*$wordToComplete*") | Write-Output | Select-Object -Unique
        })]
        [string[]]$Name
    )

    if ($MyInvocation.ExpectingInput)
    {
        $Name = $input
    }

    $Names = (ip link) -match '^\d' -replace '^\d+: ' -replace ':.*' -replace '@.*'
    if ($Name)
    {
        $Names = $Names | Where-Object {$n = $_; $Name | Where-Object {$n -like $_}}
    }
    $Names
}

function Get-NetIpAddress
{
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName, Position = 0)]
        [SupportsWildcards()]
        [ArgumentCompleter({
            param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $Names = Get-NetInterfaceName
            ($Names -like "$wordToComplete*"), ($Names -like "*$wordToComplete*") | Write-Output | Select-Object -Unique
        })]
        [string[]]$Name,

        [ValidateSet("IPv4", "IPv6")]
        [string]$AddressFamily
    )

    if ($AddressFamily)
    {
        [Net.Sockets.AddressFamily]$AddressFamily = $AddressFamily -replace "IP(v4)?", "InterNetwork"
    }

    if ($MyInvocation.ExpectingInput)
    {
        $Name = $input
    }

    $Name = $Name | Get-NetInterfaceName

    Update-TypeData -Force -TypeName InetAddress -DefaultDisplayPropertySet Name, IpAddress, Prefix, Scope
    $Pattern = 'inet(6?) (?<IpAddress>\S+)/(?<Prefix>\d+) (brd (?<Broadcast>\S+) )?scope (?<Scope>.*)'

    $Name | ForEach-Object {
        $IpText = ip address show $_ | Out-String
        $Links = $IpText -split '(?<=^|\n)(?=\d+:)' | ForEach-Object Trim | Where-Object Length
        $Links | ForEach-Object {
            $Head1, $Head2, $Addrs = $_ -split '\n', 3
            $Index, $Name, $IfProperties = $Head1 -split ': ', 3
            $Hardware = $Head2 -replace '^\s+'
            $Index = [int]$Index
            $Name = $Name

            if ($Addrs -match '(?s)^(\s*altname (?<AltName>\w+)\s*\n)?(?<Addrs>.*)')
            {
                $AltName = $Matches.AltName
                $Addrs = $Matches.Addrs
            }
            else
            {
                Write-Error "Failed to parse '$Addrs'"
            }

            $Addrs -split '\n(?=    inet)' | ForEach-Object Trim | Where-Object Length | ForEach-Object {
                $Head, $IpAddressProperties = $_ -split '\n', 2 | ForEach-Object Trim
                if ($Head -match $Pattern)
                {
                    $IpAddress = [ipaddress]$Matches.IpAddress
                    $Prefix    = $Matches.Prefix
                    $Broadcast = $Matches.Broadcast
                    $Scope     = $Matches.Scope -split ' '
                }
                else
                {
                    Write-Error "Failed to parse '$Head'"
                    return
                }

                if ($AddressFamily -and $AddressFamily -ne $IpAddress.AddressFamily)
                {
                    return
                }

                [pscustomobject]@{
                    PSTypeName          = 'InetAddress'
                    Index               = $Index
                    Name                = $Name | Write-Output
                    AltName             = $AltName
                    IfProperties        = $IfProperties
                    Hardware            = $Hardware
                    IpAddress           = $IpAddress
                    Prefix              = $Prefix
                    Scope               = $Scope
                    IpAddressProperties = $IpAddressProperties.Trim()
                }
            }
        }
    }
}
Set-Alias gnip Get-NetIpAddress
