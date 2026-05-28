#!/bin/bash
# Safety Guard
if [[ ! -f /.dockerenv ]] && [[ "$USER" != "root" ]] && [[ ! -f "/tmp/is_vulnbox" ]]; then
    echo "!!! DANGER !!! This is intended for the remote Vulnbox."
    read -p "Proceed anyway? (y/N) " confirm
    [[ $confirm != [yY] ]] && exit 1
fi

# Apply the config
if [ -f "zsh.conf" ]; then
    cat zshconfig_debian_ubuntu.conf > ~/.zshrc
    echo "Config updated successfully."
else
    echo "Error: zsh.conf not found."
    exit 1
fi
