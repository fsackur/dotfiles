enum Distro
{
    Fedora
    Ubuntu
    Debian
}

function Get-Distro
{
    [CmdletBinding()]
    param ()

    if (-not $PSBoundParameters.ContainsKey('ErrorAction'))
    {
        $ErrorActionPreference = 'Stop'
    }

    if (-not $IsLinux)
    {
        Write-Error -Exception [NotSupportedException]::new('This function is only supported on Linux') -ErrorAction Stop
    }

    [Distro]((Get-Content /etc/os-release -ErrorAction Stop) -match '^ID=' -replace '.*=')
}

function Get-RepoPackage
{
    <#
        .PARAMETER Path
        Path to a file where you want to know the package that provided it.
    #>

    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Path,

        # [Parameter(Mandatory, ValueFromPipeline)]
        # [string]$Name

        [switch]$All
    )

    process
    {
        if ($All)
        {
            $Distro = Get-Distro

            if ($Distro -eq "Fedora")
            {
                $Dnf = dnf provides $Path

                # System.Management.Automation.WhereOperatorSelectionMode
                $Dnf = $Dnf.Where({$_ -like "Repositories loaded."}, 'SkipUntil') | Select-Object -Skip 1 | Out-String

                $Stanzas = $Dnf -split '\n\n' | ForEach-Object Trim
                $Packages = @($Stanzas) -replace '(?s)\s*:.*' -match '\w'
            }
            elseif ($Distro -in "Ubuntu", "Debian")
            {
                $Packages = apt-file search $Path | Select-String -Pattern '^\S+'
            }
        }
        else
        {
            $Path = $Path | Resolve-Path
            $Packages = rpm -qf $Path
        }

        $Packages | ForEach-Object {
            [pscustomobject]@{
                Filename = $Path
                Package = $_
            }
        }

        # $Name | ForEach-Object {
        #     $Package = dnf info $_ | Select-String 'Name\s+:\s+(?<Name>.*)'
        #     if ($Package)
        #     {
        #         $Package.Matches.Groups[-1].Value
        #     }
        #     else
        #     {
        #         Write-Warning "Package $_ not found"
        #     }
        # }
    }
}


function Get-RepoPackageFiles
{
    <#
        .PARAMETER Path
        Path to a package
    #>

    [CmdletBinding()]
    param
    (
        [Parameter(ParameterSetName = 'PackageFile', Mandatory, ValueFromPipeline)]
        [string]$Path

        ## rpm -q only works on installed packages
        # [Parameter(ParameterSetName = 'PackageName', Mandatory, ValueFromPipeline)]
        # [string]$Name
    )

    process
    {
        if ($Path)
        {
            rpm --query --list --package $Path
        }
    }
}
