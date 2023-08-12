#!/usr/bin/env bash
#
#   Usage:
#       bash -c "$(curl -fsSL https://raw.githubusercontent.com/fsackur/dotfiles/chezmoi/init-computer.sh)"
#


case $(uname -v) in
    *Ubuntu*|*Debian*)
        jq_installer="apt install jq"
        bitwarden_installer="apt install snapd && snap install bw"
        ansible_installer="apt install ansible";;
    *)
        echo "Distro not supported."
        exit 1;;
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
    echo $ssh_secrets | jq -r '.[] | select(.name=="config").notes' >> ~/.ssh/config
    echo $ssh_secrets | jq -r '.[] | select(.name=="github_ed25519").login.username' > ~/.ssh/github_ed25519.pub
    echo $ssh_secrets | jq -r '.[] | select(.name=="github_ed25519").notes' > ~/.ssh/github_ed25519 && chmod 600 ~/.ssh/github_ed25519

    [[ -n "$(ssh github.com 2>&1 | grep success)" ]] || (echo "SSH auth to github.com failed" && exit 1)
fi

# Clone the ansible playbook repo
mkdir -p ~/gitroot && pushd ~/gitroot > /dev/null || exit 1
if [ ! -f ./ansible/run_ansible.sh ]; then
    git clone ssh://github.com/fsackur/ansible || exit 1
fi

# Apply the ansible playbook locally
pushd ansible
./run_ansible.sh
