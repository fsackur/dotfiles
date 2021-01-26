# PSProfile
---

Install-Module PSProfile
Import-Module PSProfile

git clone https://github.com/fsackur/dotfiles
Add-PSProfileConfigurationPath C:\dev\dotfiles\PSProfile\AllHosts.psd1

'Import-Module PSProfile' >> $PROFILE.CurrentUserAllHosts