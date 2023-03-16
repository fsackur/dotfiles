#!/usr/bin/env bash
#
#   Usage:
#       bash -c "$(curl -fsSL https://raw.githubusercontent.com/fsackur/dotfiles/chezmoi/init-computer.sh)"
#

which brew || \
    sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" && \
    (echo; echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"') >> ~/.profile && \
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"


which git || brew install git
which chezmoi || brew install chezmoi

which pwsh || \
    if [[ "$(uname)" == "Darwin" ]]; then
        brew install --cask powershell
    else
        sudo apt-get install -y wget apt-transport-https software-properties-common && \
        wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb" && \
        sudo dpkg -i packages-microsoft-prod.deb && \
        rm packages-microsoft-prod.deb && \
        sudo apt-get update && \
        sudo apt-get install -y powershell && \
        sudo apt-get clean
    fi


[[ -n "$(cat /etc/shells | grep pwsh)" ]] && chsh -s "$(which pwsh)"

which jq || brew install jq
which bw || brew install bitwarden-cli

export BW_SESSION=$(bw unlock --raw || bw login --raw)

folder_id=$(bw list folders --search SSH | jq -r '.[] | select(.name=="SSH").id')
ssh_secrets=$(bw list items --folderid $folder_id)
echo $ssh_secrets | jq -r '.[] | select(.name=="config").notes' >> ~/.ssh/config
echo $ssh_secrets | jq -r '.[] | select(.name=="github_ed25519").username' >> ~/.ssh/github_ed25519.pub
echo $ssh_secrets | jq -r '.[] | select(.name=="github_ed25519").password' >> ~/.ssh/github_ed25519

[[ -n "$(ssh github.com 2>&1 | grep success)" ]] || (echo "SSH auth to github.com failed" && exit 1)

chezmoi init fsackur/dotfiles --ssh --branch chezmoi --recurse-submodules=false --apply
