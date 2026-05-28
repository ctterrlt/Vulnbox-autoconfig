#!/bin/bash
# ==============================================================================
# VULNBOX AUTO-DEPLOYMENT SCRIPT
# RUN THIS ON YOUR LOCAL PC
# ==============================================================================

# Add this to the very top of your _auto.sh files
if [ -f /.dockerenv ] || [ "$USER" == "root" ]; then
    echo "WARNING: This script is intended to be run from your LOCAL PC, not the remote Vulnbox."
    read -p "Are you sure you want to proceed? (y/N) " confirm
    [[ $confirm != [yY] ]] && exit 1
fi

echo -e "\n===  ^=^n  TARGET CONFIGURATION ==="
read -p "Enter target remote IP: " TARGET_IP
read -p "Enter target remote username: " TARGET_USER

# --- 1. SECURE ACCESS (SSH KEYS) ---
echo -e "\n===  ^=^t^q 1. SECURING ACCESS ==="
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    echo "Generating new passwordless SSH key..."
    ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
else
    echo "Using existing SSH key."
fi

echo "Copying key to target (You may need to type the password one last time)..."
ssh-copy-id -i ~/.ssh/id_ed25519.pub "${TARGET_USER}@${TARGET_IP}"

# --- 2. GENERATE THE PAYLOAD LOCALLY ---
echo -e "\n===  ^=^t^q 2. PREPARING PAYLOAD ==="
# Everything between 'PAYLOAD_EOF' gets bundled into a temporary script
cat << 'PAYLOAD_EOF' > /tmp/vulnbox_payload.sh
#!/bin/bash

# Install Packages
yay -Syu --needed zip zsh nano git curl fastfetch lsd tty-clock cmatrix zsh-syntax-highlighting zsh-autosuggestions openssh

# Install Oh-My-Zsh (Unattended)
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Change default shell
sudo chsh -s $(which zsh) $USER

# Write the Configuration
cat << 'ZSHRC_EOF' > ~/.zshrc
export PATH="/app/extra/bin:$HOME/.local/bin:/usr/local/bin:$PATH"
export DEBUGINFOD_URLS="https://debuginfod.archlinux.org"
export EDITOR="nano"
export VISUAL="nano"
export CLICOLOR=1
export LS_COLORS='di=0;36:fi=0;37:'   

[[ $- == *i* ]] && if command -v fastfetch &>/dev/null; then
    fastfetch --color blue --logo-color-1 blue --logo-color-2 blue
    printf '\e[0m'
fi

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""   
zstyle ':omz:update' mode auto
COMPLETION_WAITING_DOTS="true"
ENABLE_CORRECTION="true"
plugins=(git)
source $ZSH/oh-my-zsh.sh

PROMPT='%F{214}%n@%m%f %F{34}%~$%f %F{white}%D{%H:%M:%S}%f '

HISTSIZE=10000
SAVEHIST=20000
export HISTCONTROL=ignoredups:ignorespace
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt autocd
setopt correct
unsetopt PROMPT_SP

# --- 6. ALIASES ---
alias fastfetch="fastfetch --color blue --logo-color-1 blue --logo-color-2 blue"
alias zshrc="nano ~/.zshrc"
alias zsh="source ~/.zshrc"
alias lss="lsd -lah --group-directories-first --icon always --color always"
alias ..="cd .."
alias ...="cd ../.."
alias pipinst='pip install --break-system-packages'
alias explain=tldr
alias installaapp1="sudo pacman -S"
alias installaapp2="yay -S"
alias aggiornaeinstalla1="sudo pacman -Syu"
alias aggiornaeinstalla2="yay -Syu"

# --- IDA Pro Bottle Launcher ---

alias ida='flatpak run --command=bottles-cli com.usebottles.bottles run -b "IDA" -p "ida"'
alias cdida='cd ~/.var/app/com.usebottles.bottles/data/bottles/bottles/IDA/drive_c/Program\ Files/IDA\ Professional\ 9.0/'

# Tools & Fun
alias cock='tty-clock -c -C 4 -r -f "%A, %B %d, %Y"'
alias matrix="cmatrix -C blue"
alias rick='echo -ne "\e[34m"; curl -s ascii.live/rick; echo -ne "\e[0m"'
alias forrest='echo -ne "\e[34m"; curl -s ascii.live/forrest; echo -ne "\e[0m"'
alias knot='echo -ne "\e[34m"; curl -s ascii.live/knot; echo -ne "\e[0m"'
alias parrot='echo -ne "\e[34m"; curl -s ascii.live/parrot; echo -ne "\e[0m"'

# AD-CTF Power Tools
alias myip="ip -br addr"
alias listening="ss -tulpn | grep LISTEN"
alias sniff="sudo tcpdump -i any -A 'tcp port 80'"

# WireGuard (Manual Selection)
alias tunnel="sudo wg-quick up"
alias untunnel="sudo wg-quick down"

# openvpn
alias vpnopen='sudo openvpn --daemon --config'
alias vpnclose="sudo killall openvpn"

# Docker
alias dps="docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
alias dlog="docker compose logs -f"
alias dbuild="docker compose up -d --build"
alias ddown="docker compose down"

clear_msg() {
    clear
    echo "Terminal cleared. Ready to go."
}

# --- Robust Plugin Loading ---

# 1. Syntax Highlighting
for plugin in /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
              /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
    if [ -f "$plugin" ]; then
        source "$plugin"
        break
    fi
done

# 2. Autosuggestions
for plugin in /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
              /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh; do
    if [ -f "$plugin" ]; then
        source "$plugin"
        break
    fi
done

ZSHRC_EOF

echo -e "\n===  ^=^t^q ENVIRONMENT DEPLOYED SUCCESSFULLY ==="
PAYLOAD_EOF

# --- 3. SHIP IT AND RUN IT ---
echo -e "\n===  ^=^t^q 3. DEPLOYING TO TARGET ==="

# Copy the script to the target machine
scp /tmp/vulnbox_payload.sh "${TARGET_USER}@${TARGET_IP}:/tmp/setup.sh"

# Connect via SSH, run the setup script, delete it to clean up traces, and launch Zsh
ssh -t "${TARGET_USER}@${TARGET_IP}" "bash /tmp/setup.sh && rm /tmp/setup.sh && exec zsh"
