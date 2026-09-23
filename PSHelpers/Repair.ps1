
#region mount and chroot
# also see: https://github.com/archlinux/arch-install-scripts/blob/master/arch-chroot.in

function Get-Mount {
    [CmdletBinding(DefaultParameterSetName = "All")]
    param (
        [Parameter(ParameterSetName = "Mountpoint", Mandatory, Position = 0)]
        [string]$Mountpoint,

        [Parameter(ParameterSetName = "Mountpoint")]
        [switch]$Recurse
    )

    $Output = mount 2>&1
    if (!$?) {
        Write-Error -ea Stop ($Output | Out-String).Trim()
    }

    $Mounts = $Output |
        % {
            if ($_ -match "(?<Device>\S+) on (?<Mountpoint>\S+) type (?<Type>\S+)( \((?<Options>.*)\))?") {
                $Matches
            } else {
                Write-Error "Could not parse '$_'"
            }
        }

    if ($PSCmdlet.ParameterSetName -ne "All") {
        $Mountpoint = $Mountpoint -replace "/$"
        $Pattern = [regex]::Escape($Mountpoint)
        $Pattern = if ($Recurse) {
            "^$Pattern($|/.+)"
        } else {
            "^$Pattern$"
        }
        $Mounts = $Mounts | ? Mountpoint -match $Pattern
    }

    $Mounts | Select-Object Device, Type, Mountpoint, Options
}

function Get-FsTab {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, ValueFromPipeline)]
        [string]$Path = "/etc/fstab"
    )

    process {
        $FsTab = gc $Path -ea Stop
        $FsTab = $FsTab -notmatch "^\s*#" -notmatch "^$"
        $FsTab | % {
            $Device, $_Mountpoint, $Type, $Options, $_ = $_ -split "\s+"
            [pscustomobject]@{
                Device = $Device
                Type = $Type
                Mountpoint = $_Mountpoint
                Options = $Options
            }
        }
    }
}

function Mount-Filesystem {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias("Name")]
        [Alias("Device")]
        [Alias("Partition")]
        [string]$Source,

        [Parameter(Mandatory, Position = 1, ValueFromPipelineByPropertyName)]
        [Alias("Target")]
        [string]$Mountpoint,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Type,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]]$Options
    )

    begin {
        if (-not $PSBoundParameters.ContainsKey('ErrorAction')) {
            $ErrorActionPreference = "Stop"
        }
    }

    process {
        $Device = if ($Source -match "^(\w+)=(.+)$" -and -not (Test-Path $Source)) {
            $BlockArg = $Matches[1].ToLower()
            $BlockArgs = "--$BlockArg", $Matches[2]
            blkid @BlockArgs
        } else {
            $Source
        }

        $Mount = Get-Mount $Mountpoint
        if ($Mount.Device -eq $Device) {
            Write-Verbose "$Source is already mounted at $Mountpoint. Skipping..."
            return
        }

        $MountArgs = [System.Collections.Generic.List[string]]::new()

        if ($Type) {
            $MountArgs.Add("-t")
            $MountArgs.Add($Type)
        }

        if ($Options) {
            $MountArgs.Add("-o")
            $MountArgs.Add($Options -join ",")
        }

        $MountArgs.Add("--source")
        $MountArgs.Add($Source)
        $MountArgs.Add("--target")
        $MountArgs.Add($Mountpoint)

        Write-Verbose "Mounting $Source to $Mountpoint..."
        $Output = sudo mount @MountArgs 2>&1
        if (!$?) {
            Write-Error -ea Stop ($Output | Out-String).Trim()
        }
    }
}

function Dismount-Filesystem {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0)]
        [string]$Mountpoint,

        [switch]$Recurse
    )

    if (-not $PSBoundParameters.ContainsKey('ErrorAction')) {
        $ErrorActionPreference = "Stop"
    }

    $Mountpoint = $Mountpoint -replace "/$"

    if (-not $Mountpoint) {
        Write-Error -ea Stop "Not unmounting /"
    }

    $Mounts = Get-Mount @PSBoundParameters | Select-Object Device, Mountpoint -Unique

    if ($Recurse) {
        # Need to unmount child mounts first; number of slashes is a decent proxy
        $Mounts = $Mounts | Sort-Object {($_.Mountpoint -replace "[^/]").Length} -Descending
    }

    if (-not $Mounts) {
        return
    }

    $Mountpoints = $Mounts.Mountpoint #| Select-Object -Unique
    $Mountpoints | % {
        Write-Verbose "Unmounting $_..."
        $Output = sudo umount $_ *>&1
        if (!$?) {
            Write-Error -ea Stop ($Output | Out-String).Trim()
        }
    }
}

function Switch-Root {
    <#
        .DESCRIPTION
        Mount a root filesystem and the fstab from within it, and chroot to it.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0)]
        [Alias("Name")]
        [Alias("Device")]
        [Alias("Partition")]
        [string]$Source,

        [Alias("Target")]
        [string]$Mountpoint = "/rescue"
    )

    if (-not $PSBoundParameters.ContainsKey('ErrorAction')) {
        $ErrorActionPreference = "Stop"
    }

    $Mountpoint = $Mountpoint -replace "/$"

    if (-not $Mountpoint) {
        Write-Error -ea Stop "Not chrooting to /"
    }

    # # mount mountpoint to itself, so findmnt has an accurate heirarchy within the chroot
    # # https://man.archlinux.org/man/arch-chroot.8
    # Mount-Filesystem $Mountpoint $Mountpoint -Options bind

    Mount-Filesystem $Source $Mountpoint

    $FsTab = Join-Path $Mountpoint "/etc/fstab" | Get-FsTab

    $FsTab = $FsTab |
        ? Type -in ("ext3", "ext4", "fat", "fat32", "vfat", "btrfs") |
        ? Mountpoint -match "^/"

    $FsTab | % {$_.Mountpoint = Join-Path $Mountpoint $_.Mountpoint}

    $FsTab | Mount-Filesystem

    $Extras = (
        @{Source = "/proc"; Type = "proc"},
        @{Source = "/sys"; Type = "sysfs"},
        @{Source = "/dev"; Options = "rbind"},
        @{Source = "/run"; Options = "bind"}
        # @{Source = "/etc/resolv.conf"; Mountpoint = "/etc/resolv.conf"; Options = "bind"}
    )
    $Extras | % {$_.Mountpoint = Join-Path $_.Source $_.Mountpoint}

    $Extras = $Extras | % {[pscustomobject]$_}

    $Extras | Mount-Filesystem

    sudo chroot $Mountpoint grep -v rootfs /proc/mounts > /etc/mtab
    if (!$?) {
        throw
    }

    sudo chroot $Mountpoint
    if (!$?) {
        throw
    }
}
#endregion mount and chroot

#region dracut and boot
function Repair-Initramfs {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
    param (
        [switch]$All
    )

    $AddVersion = {
        $_ | Add-Member -PassThru -NotePropertyMembers @{
            Version = $_.Name -replace "^.*?-"
        }
    }

    $kernels = gci /boot/vmlinuz-* | % $AddVersion | sort Version
    $inits = gci /boot/initramfs-* | % $AddVersion | sort Version

    $Versions = Compare-Object $kernels $inits -Property Version | ? SideIndicator -eq "<=" | % Version
    if (-not $Versions) {
        Write-Verbose -Verbose "All kernels have a matching initramfs."
        return
    }

    if (-not $All) {
        $Versions = $Versions | Sort-Object | Select-Object -Last 1
    }

    $Versions | % {
        $Version = $_
        if ($PSCmdlet.ShouldProcess($_, "Regenerate initramfs")) {
            sudo dracut --verbose --kver=$Version
            if (!$?) {
                throw
            }
        }
    }
}
#endregion dracut and boot

#region write images
function Write-Iso {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
    param (
        [Parameter(Mandatory)]
        [string]$Iso,

        [Parameter(Mandatory)]
        [string]$Disk,

        [ValidateRange(1, 1024)]
        [int]$DataPartitionSizeGb = 4,

        [string]$Mountpoint,

        [switch]$Force
    )

    $Iso = Resolve-Path $Iso -ErrorAction Stop

    & {
        $ErrorActionPreference = "Stop"

        $Mounted = @(mount) -like "$Disk*"
        if ($Mounted -and ($Force -or $PSCmdlet.ShouldProcess($Mounted, "unmount"))) {
            sudo umount $Mounted
        }

        # region dd
        if ($Force -or $PSCmdlet.ShouldProcess("$Iso => $Disk", "write ISO")) {
            Write-Verbose "burning $Iso"
            sudo dd if=$Iso of=$Disk bs=4M status=progress
        }
        #endregion dd

        $fdisk = "p" | sudo fdisk $Disk *>&1
        if (!$?) {throw "$fdisk"}

        $DataPart = ""
        $LastPart = $fdisk[-3]
        if ($LastPart -match "Linux filesystem$") {
            $DataPart = $LastPart -replace " .*"
        }

        if ((-not $DataPart) -and ($Force -or $PSCmdlet.ShouldProcess($Disk, "add data partition"))) {
            Write-Verbose "adding partition"

            # Command (m for help): n
            # Partition number (5-176, default 5):
            # First sector (5343868-61439954, default 5345280):
            # Last sector, +/-sectors or +/-size{K,M,G,T,P} (5345280-61439954, default 61437951): +4G
            $NewPartition = "n"
            $Primary = "p"
            $PartitionNum = ""
            $FirstSector = ""
            $LastSector = "+$($DataPartitionSizeGb)G"
            $WriteTable = "w"

            $NewPartition, $Primary, $PartitionNum, $FirstSector, $LastSector, $WriteTable |
                sudo fdisk --wipe=never $Disk

            $fdisk = "p" | sudo fdisk $Disk *>&1
            if (!$?) {throw "$fdisk"}

            $DataPart = ""
            $LastPart = $fdisk[-3]
            $DataPart = $LastPart -replace " .*"

            sudo mkfs -V --type ext3 -O sparse_super,large_file -m 0 -T largefile4 $DataPart
        }

        if (-not $Mountpoint) {
            $Name = Split-Path -Leaf $DataPart
            $Mountpoint = Join-Path /run/media $env:USER $Name
        }

        [bool]$IsMounted = (mount) -like "$DataPart *"
        if (-not $IsMounted) {
            # sudo mkdir -p $Mountpoint
            $msg = sudo mount --mkdir $DataPart $Mountpoint *>&1
            if (!$?) {throw $msg}
        }
    }
}

# function Write-LiveCd {
#     # sudo dnf in livecd-tools
#     [CmdletBinding()]
#     param (
#         [string]$OutDir = "/vm/images",
#         [string]$TmpDir = "/vm/tmp"
#     )

#     if (-not $PSBoundParameters.ContainsKey("ErrorAction")) {
#         $ErrorActionPreference = "Stop"
#     }

#     sudo dnf in livecd-tools
#     editliveos
#     image-creator
#     livecd-creator
#     liveimage-mount

#     $null = New-Item $OutDir -ItemType Directory -Force
#     Push-Location $OutDir
#     try {
#         # sudo livecd-creator -t $TmpDir -c /home/freddie/.local/share/livecd-tools/livecd-fedora.ks -f fedora-live -v

#         sudo editliveos -o $OutDir -t $TmpDir --dnfcache "$TmpDir/cache/dnf" --name fedora-live --kickstart /home/freddie/.local/share/livecd-tools/livecd-fedora.ks --extra-space-mb 2048 --compress --nocleanup -v /vm/images/Fedora-Workstation-Live-44-1.7.x86_64.iso

#     } finally {
#         Pop-Location
#     }
# }


function Write-LiveCd {
    # sudo dnf in livecd-tools
    [CmdletBinding()]
    param (
        [string]$OutDir = "/vm/images",
        [string]$TmpDir = "/vm/tmp"
    )

    if (-not $PSBoundParameters.ContainsKey("ErrorAction")) {
        $ErrorActionPreference = "Stop"
    }

    # sudo dnf in kiwi-systemdeps distribution-gpg-keys
    # pip install --user kiwi

    $DescPath = Join-Path $TmpDir fedora-kiwi-descriptions
    if (-not (Test-Path $DescPath)) {
        $null = New-Item $TmpDir -ItemType Directory -Force
        Push-Location $TmpDir
        try {
            git clone https://pagure.io/fedora-kiwi-descriptions.git
        } finally {
            Pop-Location
        }
    }

    # $BuildScript = Join-Path $DescPath kiwi-build
    # . $BuildScript --kiwi-description-dir ./ --output-dir=$OutDir --image-type=iso --image-profile=Workstation-Live --temp-dir $TmpDir

    sudo ./kiwi-build --output-dir=/vm/kiwi/out --image-type=iso --image-profile=Workstation-Live
}
#endregion write images
