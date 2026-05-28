#fedora
sudo dnf update -y && sudo dnf install -y zip zsh nano git curl neofetch lsd tty-clock cmatrix zsh-syntax-highlighting zsh-autosuggestions openssh-clients && sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended && sudo chsh -s $(which zsh) $USER

cat << 'EOF' > ~/.zshrc
#fedora based config

# --- 1. PATH & ENVIRONMENT ---
export PATH="/app/extra/bin:$HOME/.local/bin:/usr/local/bin:$PATH"
export DEBUGINFOD_URLS="https://debuginfod.fedoraproject.org"
export EDITOR="nano"
export VISUAL="nano"
export CLICOLOR=1
export LS_COLORS='di=0;36:fi=0;37:'   

# --- 2. STARTUP (Neofetch) ---
[[ $- == *i* ]] && if command -v neofetch &>/dev/null; then
    neofetch
fi

# --- 3. OH MY ZSH SETUP ---
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""   
zstyle ':omz:update' mode auto
COMPLETION_WAITING_DOTS="true"
ENABLE_CORRECTION="true"
plugins=(git)
source $ZSH/oh-my-zsh.sh
alias c3-compile='arduino-cli compile --fqbn esp32:esp32:esp32c3'

# --- 4. THE "Chry@Chry" PROMPT ---
PROMPT='%F{214}%n@%m%f %F{34}%~$%f %F{white}%D{%H:%M:%S}%f '

# --- 5. HISTORY & BEHAVIOR ---
HISTSIZE=10000
SAVEHIST=20000
export HISTCONTROL=ignoredups:ignorespace
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt autocd
setopt correct
unsetopt PROMPT_SP

# --- 6. ALIASES ---
alias neofetch="neofetch"
alias zshrc="nano ~/.zshrc"
alias zsh="source ~/.zshrc"
alias lss="lsd -lah --group-directories-first --icon always --color always"
alias ..="cd .."
alias ...="cd ../.."
alias pipinst='pip install --break-system-packages'
alias explain=tldr
alias installaapp1="sudo dnf install"
alias installaapp2="flatpak install"
alias aggiornaeinstalla1="sudo dnf upgrade -y"
alias aggiornaeinstalla2="flatpak update -y"

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
    echo "Terminal cleared. Ready to go."
}

# --- 8. FEDORA PLUGIN FIX ---
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh 2>/dev/null
source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh 2>/dev/null
alias bottles="flatpak run com.usebottles.bottles"
EOF

# standard one-liner to use later
echo -e "\n===  ^=^l^p LOCAL NETWORK INTERFACES ==="
ip -br addr

echo -e "\n===  ^=^n  TARGET CONFIGURATION ==="
echo -n "Enter target remote IP (or press Enter to skip): "
read TARGET_IP

if [ -n "$TARGET_IP" ]; then
    echo -n "Enter target remote username: "
    read TARGET_USER

    echo -e "\n===  ^=^t^q DEPLOYING SSH KEY ==="
    
    # 1. Check if the key already exists to prevent overwriting
    if [ -f "$HOME/.ssh/id_ed25519" ]; then
        echo "Existing SSH key found at ~/.ssh/id_ed25519. Skipping generation."
    else
        echo "No SSH key found. Generating a new passwordless Ed25519 key..."
        ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
    fi

    # 2. Copy the public key to the target machine
    echo "Copying key to ${TARGET_USER}@${TARGET_IP}..."
    ssh-copy-id -i ~/.ssh/id_ed25519.pub "${TARGET_USER}@${TARGET_IP}" || \
    (cat ~/.ssh/id_ed25519.pub | ssh "${TARGET_USER}@${TARGET_IP}" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys")
else
    echo "Skipping SSH deployment."
fi
exec zsh
