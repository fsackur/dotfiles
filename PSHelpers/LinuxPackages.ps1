enum Distro
{
    Fedora
    Ubuntu
    Debian
    Unknown
}

enum PackageManager
{
    Rpm
    Deb
    Unknown
}

function Get-Distro
{
    [CmdletBinding()]
    param
    (
        [switch]$NameOnly
    )

    if (-not $PSBoundParameters.ContainsKey('ErrorAction'))
    {
        $ErrorActionPreference = 'Stop'
    }

    if (-not $IsLinux)
    {
        Write-Error -Exception [NotSupportedException]::new('This function is only supported on Linux') -ErrorAction Stop
    }

    $DistroName = (Get-Content /etc/os-release -ErrorAction Stop) -match '^ID=' -replace '.*=' | Select-Object -First 1

    if ($NameOnly)
    {
        return $DistroName
    }

    $Distro = try
    {
        [Distro]$DistroName
    }
    catch
    {
        [Distro]::Unknown
    }

    $PackageManager = switch ($Distro)
    {
        ([Distro]::Fedora) {[PackageManager]::Rpm}
        ([Distro]::Debian) {[PackageManager]::Deb}
        ([Distro]::Ubuntu) {[PackageManager]::Deb}
        default
        {
            $Debs = if (Get-Command dpkg -ErrorAction Ignore) {dpkg -l}
            $Rpms = if (Get-Command rpm -ErrorAction Ignore) {rpm -qa}

            if ($Rpms.Count -gt 10 -and $Rpms.Count -gt $Debs.Count)
            {
                [PackageManager]::Rpm
            }
            elseif ($Debs.Count -gt 10 -and $Debs.Count -gt $Rpms.Count)
            {
                [PackageManager]::Deb
            }
            else
            {
                [PackageManager]::Unknown
            }
            [PackageManager]::Unknown
        }
    }

    [pscustomobject]@{
        Name = $DistroName
        Distro = $Distro
        PackageManager = $PackageManager
    }
}

function Find-RepoPackageProvidingFile
{
    <#
        .PARAMETER Path
        Path to a file where you want to know the package that provided it.
    #>

    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [SupportsWildcards()]
        [string]$Path
    )

    begin
    {
        $PackageManager = (Get-Distro).PackageManager
    }

    process
    {
        if ($PackageManager -eq "rpm")
        {
            # search installed packages
            rpm -qf $Path | % {
                [pscustomobject]@{
                    Package = $_
                    Path = $Path
                }
            }

            if (!$?) {
                $packageFile = @{}
                $matchers = @($null, $null)
                $expectPkgName = {
                    if ($_ -match '^(\S+\.\S+)\s+:') {
                        $packageFile.Package = $Matches[1]
                        [array]::Reverse($matchers)
                    }
                }
                $expectFileName = {
                    if ($_ -match "^Filename\s+:\s+(.*)") {
                        $packageFile.Path = $Matches[1]
                        [array]::Reverse($matchers)
                        [pscustomobject]$packageFile | Write-Output
                    }
                }
                $matchers[0] = $expectPkgName
                $matchers[1] = $expectFileName
                $reader = {$_ | & $matchers[0]}

                # search repos
                dnf provides $Path | % $reader
            }
        }
        elseif ($PackageManager -eq "deb")
        {
            apt-file search $Path | Select-String -Pattern '^\S+'
        }
        else
        {
            Write-Error -Exception [NotImplementedException]::new('Only RPM and DEB packages are supported') -ErrorAction Stop
        }
    }
}

function Get-RepoPackageFiles
{
    <#
        .PARAMETER Path
        Path to a .deb or .rpm package

        .PARAMETER Name
        Name of an installed package
    #>

    [CmdletBinding()]
    param
    (
        [Parameter(ParameterSetName = 'PackageFile', Mandatory, ValueFromPipeline, Position = 0)]
        [string]$Path,

        ## rpm -q only works on installed packages
        [Parameter(ParameterSetName = 'PackageName', Mandatory, ValueFromPipeline)]
        [string]$Name
    )

    begin
    {
        $PackageManager = $null
    }

    process
    {
        if ($PSCmdlet.ParameterSetName -eq 'PackageFile')
        {
            if ($Path -notmatch '/' -and -not (Test-Path $Path))
            {
                Write-Warning "'$Path' looks like a package name. Retrying as name."
                return Get-RepoPackageFiles -Name $Path
            }

            if ($Path -match '\.rpm$')
            {
                rpm --query --list --package $Path
            }
            elseif ($Path -match '\.deb$')
            {
                dpkg --contents $Path
            }
            else
            {
                Write-Error -Exception [NotImplementedException]::new('Only RPM and DEB packages are supported') -ErrorAction Stop
            }
        }
        else
        {
            if (-not $PackageManager) {$PackageManager = (Get-Distro).PackageManager}

            if ($PackageManager -eq "rpm")
            {
                rpm --query --list $Name

                if (!$?) {
                    dnf repoquery --files $Name
                }
            }
            elseif ($PackageManager -eq "deb")
            {
                dpkg --listfiles $Name
            }
            else
            {
                Write-Error -Exception [NotImplementedException]::new('Only RPM and DEB packages are supported') -ErrorAction Stop
            }
        }
    }
}
