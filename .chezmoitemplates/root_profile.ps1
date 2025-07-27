if ($env:SUDO_USER) {
    $OrigProfile = "/home/$env:SUDO_USER/.config/powershell/profile.ps1"

    if (Test-Path $OrigProfile) {
        . $OrigProfile
    }
}
