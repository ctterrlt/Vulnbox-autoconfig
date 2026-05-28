#!/bin/bash
# ==============================================================================
# DEBIAN/UBUNTU AUTO-DEPLOYMENT SCRIPT
# RUN THIS ON YOUR LOCAL PC
# ==============================================================================

echo -e "\n===  ^=^n  TARGET CONFIGURATION ==="
read -p "Enter target remote IP: " TARGET_IP
read -p "Enter target remote username: " TARGET_USER

# --- 1. SECURE ACCESS (SSH KEYS) ---
echo -e "\n===  ^=^t^q 1. SECURING ACCESS ==="
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    echo "Generating new passwordless SSH key..."
    ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
fi

echo "Copying key to target (You may need to type the password one last time)..."
ssh-copy-id -i "${TARGET_USER}@${TARGET_IP}"

# --- 2. GENERATE THE PAYLOAD LOCALLY ---
echo -e "\n===  ^=^t^q 2. PREPARING PAYLOAD ==="
cat << 'PAYLOAD_EOF' > /tmp/vulnbox_payload_deb.sh
#!/bin/bash

# Update and Install Packages
sudo apt update && sudo apt install -y zip zsh git curl neofetch lsd tty-clock cmatrix zsh-syntax-highlighting zsh-autosuggestions openssh-client

# Install Oh-My-Zsh (Unattended)
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Change default shell
sudo chsh -s $(which zsh) $USER

# Write the Configuration
cat << 'ZSHRC_EOF' > ~/.zshrc
export PATH="/app/extra/bin:$HOME/.local/bin:/usr/local/bin:$PATH"
export EDITOR="nano"
export VISUAL="nano"
export CLICOLOR=1
export LS_COLORS='di=0;36:fi=0;37:'

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""
plugins=(git)
source $ZSH/oh-my-zsh.sh

PROMPT='%F{214}%n@%m%f %F{34}%~$%f %F{white}%D{%H:%M:%S}%f '

setopt HIST_IGNORE_DUPS HIST_IGNORE_SPACE autocd correct


alias neofetch="neofetch --color blue --logo-color-1 blue --logo-color-2 blue"
alias zshrc="nano ~/.zshrc"
alias zsh="source ~/.zshrc"
alias lss="lsd -lah --group-directories-first --icon always --color always"
alias ..="cd .."
alias ...="cd ../.."
alias pipinst='pip install --break-system-packages'
alias explain=tldr

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

# --- 7. FUNCTIONS ---
clear_msg() {
    clear
    echo "Terminal cleared. Ready to go, Chry."
}

source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh 2>/dev/null
source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh 2>/dev/null
ZSHRC_EOF

echo -e "\n===  ^=^t^q DEBIAN/UBUNTU DEPLOYED SUCCESSFULLY ==="
PAYLOAD_EOF

# --- 3. SHIP IT AND RUN IT ---
echo -e "\n===  ^=^t^q 3. DEPLOYING TO TARGET ==="
scp /tmp/vulnbox_payload_deb.sh "${TARGET_USER}@${TARGET_IP}:/tmp/setup.sh"
ssh -t "${TARGET_USER}@${TARGET_IP}" "bash /tmp/setup.sh && rm /tmp/setup.sh && exec zsh"
