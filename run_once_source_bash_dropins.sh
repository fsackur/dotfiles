#! /usr/bin/bash

# Ensure .bash_profile sources .bashrc
grep ".bashrc" "$HOME/.bash_profile" > /dev/null || cat << 'EOF' >> $HOME/.bash_profile

if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi
EOF

# Fedora default .bashrc looks for .bashrc.d
grep ".bashrc.d" "$HOME/.bashrc" > /dev/null || cat << 'EOF' >> $HOME/.bashrc

if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*; do
        if [ -f "$rc" ]; then
            . "$rc"
        fi
    done
fi
unset rc
EOF
