#!/bin/bash
# VULNBOX AUTO-DEPLOYMENT SCRIPT (DEBIAN/UBUNTU)
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── 1. SAFETY GUARD ───────────────────────────────────────────────────────────
# Warn if running inside a Docker container (likely the wrong machine)
if [ -f /.dockerenv ] || grep -qE '(docker|containerd|lxc)' /proc/1/cgroup 2>/dev/null; then
    echo "WARNING: This script is intended to be run from your LOCAL PC."
    read -rp "Are you sure? (y/N) " confirm
    [[ $confirm != [yY] ]] && exit 1
fi

# ── 2-4. SSH SETUP ────────────────────────────────────────────────────────────
. "$DIR/../sshconf.sh"

# ── 5. GENERATE PAYLOAD ───────────────────────────────────────────────────────
echo -e "\n=== 2. DEPLOYING PAYLOAD ==="

# The box may already have a Neovim config — only deploy ours if asked.
read -rp "Deploy the Neovim config to ~/.config/nvim/init.lua on the target? (y/N) " DEPLOY_NVIM

# Optionally push the shared git aliases to the target's ~/.gitconfig.
read -rp "Deploy the git aliases (gitconfig.conf) to the target's ~/.gitconfig? (y/N) " DEPLOY_GIT

# Backups can be huge — opt in, and pick exactly what to archive (not always home).
read -rp "Pull a backup from the target before finishing? (y/N) " DO_BACKUP
BACKUP_PATHS=""
BACKUP_DEST="$HOME"
if [[ $DO_BACKUP == [yY] ]]; then
    DO_BACKUP=y
    # Show what's in the target's home so you can choose folders by name (lsd if present).
    echo "--- contents of the target's home directory ---"
    ssh -p "$TARGET_PORT" "${TARGET_USER}@${TARGET_IP}" \
        'cd ~ && { command -v lsd >/dev/null 2>&1 && lsd -lah || ls -lah; }' || true
    echo "-----------------------------------------------"
    echo "Paths may be: a name under home (Immagini), a ~ path (~/Immagini), or an"
    echo "absolute path (/var/www, /etc/nginx); a trailing slash is fine."
    while true; do
        read -rp "Folder(s) to zip — e.g. Immagini, ~/Immagini, or /abs/path (space-separated), blank = whole home: " BACKUP_PATHS
        if [[ -z "$BACKUP_PATHS" ]]; then
            read -rp "No folders selected — zip the WHOLE home dir? ([y]es / [r]e-enter / [n]o backup) " ans
            case "$ans" in
                [yY]) echo "  -> backing up the whole home directory."; break ;;
                [rR]) continue ;;
                *)    DO_BACKUP=n; echo "  -> backup cancelled."; break ;;
            esac
        else
            # Normalize bare names to ~/name and show where each resolves on the target.
            _norm=""
            for _p in $BACKUP_PATHS; do
                case "$_p" in
                    /*|"~"|"~/"*) _q="$_p" ;;
                    *)            _q="~/$_p" ;;
                esac
                _norm+="${_norm:+ }$_q"
            done
            BACKUP_PATHS="$_norm"
            echo "Selected for backup (on the target):"
            for _p in $BACKUP_PATHS; do
                case "$_p" in */) echo "    - $_p" ;; *) echo "    - $_p/" ;; esac
            done
            read -rp "Proceed with these? [Y]es (Enter) / [r]e-enter: " ans
            if [[ "$ans" == [rR] ]]; then continue; fi
            break
        fi
    done
    if [[ $DO_BACKUP == y ]]; then
        echo
        read -rp "Where should the pulled backup be saved locally? [${HOME}]: " BACKUP_DEST
        BACKUP_DEST="${BACKUP_DEST:-$HOME}"
        case "$BACKUP_DEST" in
            "~")   BACKUP_DEST="$HOME" ;;
            "~/"*) BACKUP_DEST="$HOME/${BACKUP_DEST#\~/}" ;;
        esac
        mkdir -p "$BACKUP_DEST"
    fi
else
    DO_BACKUP=n
fi

cat << 'PAYLOAD_EOF' > /tmp/vulnbox_payload.sh
#!/bin/bash
set -euo pipefail

# Prime sudo once up front so the prompt is clear (not buried in package output)
# and cached for the rest of the run. This runs ON the vulnbox via `ssh -t`, so
# the password requested is the REMOTE box's, NOT your local machine's.
echo ">>> sudo below wants the password of $(whoami)@$(hostname) — the REMOTE vulnbox, not your local PC."
sudo -v

# Install packages
# Note: fastfetch, lsd, tty-clock are not in default apt repos.
# Add their PPAs or install manually if apt fails to find them.
sudo apt update && sudo apt install -y \
    zip zsh nano git curl \
    neofetch lsd tty-clock cmatrix \
    zsh-syntax-highlighting zsh-autosuggestions \
    openssh-server

# Install Oh-My-Zsh (non-interactive, skip if already present)
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Change default shell to zsh
sudo chsh -s "$(which zsh)" "$USER"

# Apply config
mv /tmp/zshconfig_debian_ubuntu.conf ~/.zshrc

# Apply Neovim config (only if it was transferred — user opted in)
if [ -f /tmp/nvimconfig.lua ]; then
    # apt installs neovim only if missing or upgradable; skips it if up to date
    sudo apt install -y neovim
    mkdir -p ~/.config/nvim
    mv /tmp/nvimconfig.lua ~/.config/nvim/init.lua
fi

# Apply git aliases (only if transferred — user opted in). Link via include.path
# so the aliases live in their own file and ~/.gitconfig stays clean.
if [ -f /tmp/gitconfig.conf ]; then
    mv /tmp/gitconfig.conf ~/.gitconfig_vulnbox
    if ! git config --global --get-all include.path 2>/dev/null | grep -qxF "$HOME/.gitconfig_vulnbox"; then
        git config --global --add include.path "$HOME/.gitconfig_vulnbox"
    fi
    echo "Git aliases linked into ~/.gitconfig."
fi

# Backup selected folders, only when requested. DO_BACKUP/BACKUP_PATHS are injected
# via the ssh command below; an empty BACKUP_PATHS falls back to the home dir.
if [ "${DO_BACKUP:-n}" = "y" ]; then
    cd ~   # so bare names (e.g. Immagini) resolve relative to home
    read -ra _backup_paths <<< "${BACKUP_PATHS:-$HOME}"
    # Expand a leading ~ / ~/ ourselves — it came from a variable, so the shell won't.
    for _i in "${!_backup_paths[@]}"; do
        case "${_backup_paths[$_i]}" in
            "~")   _backup_paths[$_i]="$HOME" ;;
            "~/"*) _backup_paths[$_i]="$HOME/${_backup_paths[$_i]#\~/}" ;;
        esac
    done
    echo "Backing up: ${_backup_paths[*]}"
    rm -f ~/backup.zip
    zip -r ~/backup.zip "${_backup_paths[@]}" -x "$HOME/backup.zip"
else
    echo "Backup skipped (not requested)."
fi

echo "Deployment complete."
PAYLOAD_EOF

# ── 5. TRANSFER & EXECUTE ─────────────────────────────────────────────────────
scp -P "$TARGET_PORT" "$DIR/zshconfig_debian_ubuntu.conf" "${TARGET_USER}@${TARGET_IP}:/tmp/zshconfig_debian_ubuntu.conf"
if [[ $DEPLOY_NVIM == [yY] ]]; then
    scp -P "$TARGET_PORT" "$DIR/../nvimconfig.lua"        "${TARGET_USER}@${TARGET_IP}:/tmp/nvimconfig.lua"
else
    # Clear any stale copy from a previous run so the payload doesn't apply it
    ssh -p "$TARGET_PORT" "${TARGET_USER}@${TARGET_IP}" "rm -f /tmp/nvimconfig.lua"
fi
if [[ $DEPLOY_GIT == [yY] ]]; then
    scp -P "$TARGET_PORT" "$DIR/../gitconfig.conf"        "${TARGET_USER}@${TARGET_IP}:/tmp/gitconfig.conf"
else
    ssh -p "$TARGET_PORT" "${TARGET_USER}@${TARGET_IP}" "rm -f /tmp/gitconfig.conf"
fi
scp -P "$TARGET_PORT" /tmp/vulnbox_payload.sh             "${TARGET_USER}@${TARGET_IP}:/tmp/setup.sh"

echo -e "\n=== 3. RUNNING REMOTE SETUP ==="
echo "Note: the remote setup runs sudo on the TARGET. If asked for a password, enter the"
echo "      password for ${TARGET_USER}@${TARGET_IP} (the vulnbox) — NOT your local machine."
ssh -p "$TARGET_PORT" -t "${TARGET_USER}@${TARGET_IP}" "DO_BACKUP='$DO_BACKUP' BACKUP_PATHS='$BACKUP_PATHS' bash /tmp/setup.sh && rm /tmp/setup.sh"

if [[ $DO_BACKUP == y ]]; then
    echo -e "\n=== 4. PULLING BACKUP ==="
    echo "Moving backup.zip to ${BACKUP_DEST}/backup_from_${TARGET_IP}.zip"
    scp -P "$TARGET_PORT" "${TARGET_USER}@${TARGET_IP}:~/backup.zip" "${BACKUP_DEST}/backup_from_${TARGET_IP}.zip"
else
    echo -e "\n=== 4. BACKUP SKIPPED ==="
fi

echo -e "\n=== 5. LOGGING IN ==="
ssh -p "$TARGET_PORT" -t "${TARGET_USER}@${TARGET_IP}" "exec zsh"
