#!/usr/bin/env bash
#
#   Usage:
#       bash -c "$(curl -fsSL https://raw.githubusercontent.com/fsackur/dotfiles/chezmoi/init-computer.sh)"
#


case $(cat /etc/lsb-release) in
    *Ubuntu*|*Debian*)
        jq_installer="apt install jq"

        # works, but fuck snap
        # bitwarden_installer="apt install snapd && snap install bw"

        tags="$(curl https://api.github.com/repos/bitwarden/clients/git/refs/tags)"
        tag="$(echo $tags | jq -r '.[] | select(.ref | startswith("refs/tags/cli")) | .ref' | tail -n 1 | sed 's|.*/||')"
        release=$(curl https://api.github.com/repos/bitwarden/clients/releases/tags/$tag)
        url="$(echo $release | jq -r '.assets | .[] | select(.name | startswith("bw-linux")) | select(.name | endswith(".zip")) | .browser_download_url')"
        file="$(echo $url | sed 's|.*/||')"
        bitwarden_installer="apt install unzip && wget $url && unzip -o $file -d /usr/local/bin/ && chmod +x /usr/local/bin/bw && rm $file"
        ansible_installer="apt install ansible";;
    *)
        if [ -d /usr/lib/rpm/suse ]; then
            jq_installer="zypper install jq"
            bitwarden_installer="zypper install flatpak && flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo && flatpak install com.bitwarden.desktop"
            ansible_installer="zypper install ansible"
        else
            echo "Distro not supported."
            exit 1
        fi;;
esac

if [ ! "$(which jq)" ]; then
    echo "==================================="
    echo "Installing jq..."
    sudo bash -c "$jq_installer"
fi

if [ ! "$(which bw)" ]; then
    echo "==================================="
    echo "Installing Bitwarden CLI..."
    sudo bash -c "$bitwarden_installer"
fi

if [ ! "$(which ansible)" ]; then
    echo "==================================="
    echo "Installing Ansible..."
    sudo bash -c "$ansible_installer"
fi

# Can we clone from github?
if [ ! "$(ssh github.com 2>&1 | grep success)" ]; then
    if [ ! "$BW_SESSION" ]; then
        echo "==================================="
        echo "Log into Bitwarden..."
        export BW_SESSION=$(bw unlock --raw || bw login --raw)
    fi

    folder_id=$(bw list folders --search SSH | jq -r '.[] | select(.name=="SSH").id')
    ssh_secrets=$(bw list items --folderid $folder_id)

    mkdir -p ~/.ssh
    config=$(echo $ssh_secrets | jq -r '.[] | select(.name=="config").notes')
    printf "%s\n" "${config[@]}" >> ~/.ssh/config && chmod 600 ~/.ssh/config

    key_names=$(echo $ssh_secrets | jq -r '.[] | select(.name!="config").name')
    for key_name in $key_names; do
        key=$(echo $ssh_secrets | jq -r ".[] | select(.name==\"${key_name}\")")
        pubkey=$(echo $key | jq -r '.login.username')
        privkey=$(echo $key | jq -r '.notes')
        printf "%s\n" "${pubkey[@]}" > ~/.ssh/$key_name.pub
        printf "%s\n" "${privkey[@]}" > ~/.ssh/$key_name && chmod 600 ~/.ssh/$key_name
    done

    [[ -n "$(ssh github.com 2>&1 | grep success)" ]] || (echo "SSH auth to github.com failed" && exit 1)
fi

read -n 1 -a response -p "Run ansible playbook for $(hostname)? [y/N] "
echo
if [ ${response,,} != "y" ]; then
    exit 0
fi

folder=~/gitroot
if [ ! -f "$folder/ansible/run_ansible.sh" ]; then
    read -a response -p "Root folder to clone ansible playbook repo into? [$folder] "
    echo
    if [ $response ]; then folder=$response; fi
fi

# Clone the ansible playbook repo
mkdir -p $folder && pushd $folder > /dev/null || exit 1
if [ ! -f "$folder/ansible/run_ansible.sh" ]; then
    git clone ssh://github.com/fsackur/ansible --filter=blob:none || exit 1
fi

# Apply the ansible playbook locally
$folder/ansible/run_ansible.sh
