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

function Test-Loopback
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [ipaddress]$Address
    )

    process
    {
        return $Address.IPAddressToString -eq "::1" -or $Address.IPAddressToString -match "^127\."
    }
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
        [string]$AddressFamily,

        [switch]$IncludeLoopback
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

            if ($Addrs -match '(?s)^(\s*altname (?<AltName>\w+)\s*)?(?<Addrs>.*)')
            {
                $AltName = $Matches.AltName
                $Addrs = $Matches.Addrs
            }
            else
            {
                Write-Error "Failed to parse '$Addrs'"
                $AltName = $null
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

                $IsLoopback = Test-Loopback $IpAddress
                if ($IsLoopback -and -not $IncludeLoopback)
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
                    CidrAddress         = $IpAddress, $Prefix -join '/'
                    IsLoopback          = $IsLoopback
                    Scope               = $Scope
                    IpAddressProperties = $IpAddressProperties.Trim()
                }
            }
        }
    }
}
Set-Alias gnip Get-NetIpAddress

function Add-NetIpAddress {
    [CmdletBinding(DefaultParameterSetName = "ByCidrAddress", SupportsShouldProcess, ConfirmImpact = "High")]
    param
    (
        [Parameter(Mandatory, Position = 0)]
        [SupportsWildcards()]
        [ArgumentCompleter({
            param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $Names = Get-NetInterfaceName
            ($Names -like "$wordToComplete*"), ($Names -like "*$wordToComplete*") | Write-Output | Select-Object -Unique
        })]
        [string]$Name,

        [Parameter(ParameterSetName = "ByCidrAddress", Mandatory, Position = 1)]
        [string]$CidrAddress,

        [Parameter(ParameterSetName = "ByAddressAndMask", Mandatory, Position = 1)]
        [ipaddress]$Address,

        [Parameter(ParameterSetName = "ByAddressAndMask", Mandatory)]
        [ValidateRange(1, 32)]
        [int]$Mask,

        [switch]$Force,

        [ValidateRange(0, [int]::MaxValue)]
        [int]$LifetimeSecs = 0,

        [switch]$NoDuplicateAddressDetection,

        [switch]$NoPrefixRoute
    )

    if ($PSCmdlet.ParameterSetName -eq "ByCidrAddress") {
        [void]$PSBoundParameters.Remove("CidrAddress")
        $Address, $Mask = $CidrAddress -split "/", 2
        return & $MyInvocation.MyCommand -Address $Address -Mask $Mask @PSBoundParameters
    }

    $CidrAddress = $Address, $Mask -join '/'

    $Lifetime = if ($LifetimeSecs) {"preferred_lft", $LifetimeSecs} else {"preferred_lft", "forever"}

    $IpArgs = @()

    if ($NoDuplicateAddressDetection) {$IpArgs += "nodad"}
    if ($NoPrefixRoute) {$IpArgs += "noprefixroute"}

    if ($Force -or $PSCmdlet.ShouldProcess($Name, "add $CidrAddress")) {
        sudo ip address add $CidrAddress dev $Name @Lifetime @IpArgs
    }
}
Set-Alias anip Add-NetIpAddress

function Remove-NetIpAddress {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
    param
    (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [SupportsWildcards()]
        [ArgumentCompleter({
            param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

            $NameSplat = if ($fakeBoundParameters.Name) {@{Name = $fakeBoundParameters.Name}} else {@{}}
            $CidrAddresses = Get-NetIpAddress @NameSplat -IncludeLoopback |
                Sort-Object IsLoopback, IpAddress |
                % CidrAddress

            ($CidrAddresses -like "$wordToComplete*"), ($CidrAddresses -like "*$wordToComplete*") | Write-Output | Select-Object -Unique
        })]
        [Alias('Address', 'IpAddress')]
        [string]$CidrAddress,

        [Parameter()]
        [SupportsWildcards()]
        [ArgumentCompleter({
            param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $Names = Get-NetInterfaceName
            ($Names -like "$wordToComplete*"), ($Names -like "*$wordToComplete*") | Write-Output | Select-Object -Unique
        })]
        [string]$Name,

        [switch]$Force
    )

    $CidrAddresses = if ($MyInvocation.ExpectingInput) {$input} else {$CidrAddress}

    [void]$PSBoundParameters.Remove("CidrAddress")
    [void]$PSBoundParameters.Remove("Force")

    foreach ($CidrAddress in $CidrAddresses) {
        Get-NetIpAddress @PSBoundParameters |
            ? {$_.CidrAddress -like $CidrAddress -or $_.IpAddress.IPAddressToString -like $CidrAddress} |
            ? {$Force -or $PSCmdlet.ShouldProcess($_.Name, "del $($_.CidrAddress)")} |
            % {sudo ip address del $_.CidrAddress dev $_.Name}
    }
}
Set-Alias rnip Remove-NetIpAddress

Update-TypeData -Force -TypeName InetAddress -DefaultDisplayPropertySet Name, IpAddress, Prefix, Scope
