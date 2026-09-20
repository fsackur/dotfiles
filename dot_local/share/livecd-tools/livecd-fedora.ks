lang en_GB.UTF-8
keyboard gb
timezone Europe/London
authselect select sssd with-silent-lastlog --force
selinux --enforcing
firewall --disabled
part / --size 4096

repo --name=development --mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=rawhide&arch=$basearch
repo --name=copr:copr.fedorainfracloud.org:sergiomb:clonezilla --baseurl=https://download.copr.fedorainfracloud.org/results/sergiomb/clonezilla/fedora-$releasever-$basearch/ --install
repo --name=packages-microsoft-com-prod --baseurl=https://packages.microsoft.com/rhel/9.0/prod --excludepkgs=dotnet*,aspnet*,netstandard* --install
repo --name=carapace --baseurl=https://yum.fury.io/rsteube --install

%packages
@standard
gparted
clonezilla
powershell
carapace-bin
carapace-bridge

%end
