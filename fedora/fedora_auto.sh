#!/bin/bash
# VULNBOX AUTO-DEPLOYMENT SCRIPT (FEDORA)
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── 1. SAFETY GUARD ───────────────────────────────────────────────────────────
# The docker check exists because CTF vulnboxes are often Docker containers.
# If you accidentally run this script *inside* one of those containers instead
# of from your local PC, it would overwrite the container's config and try to
# SSH into itself. The check catches that case before any damage is done.
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

# The TLS bridge runs ON the vulnbox (unlike the xfarm exploits) — offer to ship it.
read -rp "Deploy the TLS interception bridge (python_exploits/tls) to ~/tls_bridge on the target? (y/N) " DEPLOY_TLS

# After everything else, optionally clone this toolkit's own dev branch onto the box.
read -rp "Also clone this toolkit's dev branch into ~/<repo> on the target once setup finishes? (y/N) " DEPLOY_DEV
DEV_REPO_URL=""
DEV_REPO_NAME=""
DEV_REPO_BRANCH="dev"
if [[ $DEPLOY_DEV == [yY] ]]; then
    # Derive the clone URL from this checkout's origin; rewrite an SSH remote to its
    # HTTPS form so the vulnbox needs no GitHub key of its own.
    DEV_REPO_URL=$(git -C "$DIR" remote get-url origin 2>/dev/null || true)
    if [[ $DEV_REPO_URL == git@*:* ]]; then
        _hp=${DEV_REPO_URL#git@}; DEV_REPO_URL="https://${_hp%%:*}/${_hp#*:}"
    elif [[ $DEV_REPO_URL == ssh://git@* ]]; then
        DEV_REPO_URL="https://${DEV_REPO_URL#ssh://git@}"
    fi
    if [[ -z $DEV_REPO_URL ]]; then
        echo "  Couldn't determine this repo's origin URL — skipping the dev clone."
    else
        DEV_REPO_NAME=$(basename "$DEV_REPO_URL" .git)
        echo "  Will clone $DEV_REPO_URL (branch $DEV_REPO_BRANCH) into ~/$DEV_REPO_NAME on the target after setup."
    fi
fi

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

# Install packages. Core first — including zsh-syntax-highlighting + zsh-autosuggestions,
# which the deployed .zshrc sources from /usr/share (without them, typed commands show
# no color). The cosmetic extras use dnf's --skip-unavailable so a package missing from
# the repos (neofetch is discontinued, tty-clock isn't always packaged) is dropped
# instead of aborting the whole transaction (dnf5 fails the lot otherwise).
sudo dnf install -y zip zsh nano git curl openssh-server \
    zsh-syntax-highlighting zsh-autosuggestions
sudo dnf install -y --skip-unavailable fastfetch lsd tty-clock cmatrix

# Install Oh-My-Zsh (non-interactive, skip if already present)
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Change default shell to zsh
sudo chsh -s "$(which zsh)" "$USER"

# Apply config
mv /tmp/zshconfig_fedora.conf ~/.zshrc

# Apply Neovim config (only if it was transferred — user opted in)
if [ -f /tmp/nvimconfig.lua ]; then
    # dnf installs neovim only if missing or upgradable; skips it if up to date
    sudo dnf install -y neovim
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

# Deploy the TLS interception bridge (only if transferred — user opted in). Its
# runtime is stdlib-only, so there's nothing to install; just drop the folder in
# the home dir and make its scripts executable. Configure/run on the box with:
#   cd ~/tls_bridge && ./auto_tls.sh && python3 tls.py
if [ -d /tmp/tls_bridge ]; then
    rm -rf ~/tls_bridge
    mv /tmp/tls_bridge ~/tls_bridge
    chmod +x ~/tls_bridge/*.sh ~/tls_bridge/tls.py 2>/dev/null || true
    echo "TLS bridge deployed to ~/tls_bridge — configure with: cd ~/tls_bridge && ./auto_tls.sh"
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

# Clone this toolkit's dev branch onto the box, only when requested. Runs last — git
# is installed by now. DEV_REPO_* are injected on the ssh line; the URL is HTTPS so
# the box needs no GitHub key. An existing checkout is updated, never clobbered.
if [ -n "${DEV_REPO_URL:-}" ]; then
    if [ -d "$HOME/${DEV_REPO_NAME}/.git" ]; then
        echo "~/${DEV_REPO_NAME} is already a git repo — updating ${DEV_REPO_BRANCH}."
        git -C "$HOME/${DEV_REPO_NAME}" fetch origin "${DEV_REPO_BRANCH}" \
            && git -C "$HOME/${DEV_REPO_NAME}" checkout "${DEV_REPO_BRANCH}" \
            && git -C "$HOME/${DEV_REPO_NAME}" pull --ff-only \
            || echo "  (update failed — leaving the existing checkout untouched)"
    else
        echo "Cloning ${DEV_REPO_URL} (branch ${DEV_REPO_BRANCH}) into ~/${DEV_REPO_NAME}..."
        git clone -b "${DEV_REPO_BRANCH}" "${DEV_REPO_URL}" "$HOME/${DEV_REPO_NAME}" \
            || echo "  (clone failed — check network/branch name)"
    fi
fi

echo "Deployment complete."
PAYLOAD_EOF

# ── 5. TRANSFER & EXECUTE ─────────────────────────────────────────────────────
scp $SCP_OPTS -P "$TARGET_PORT" "$DIR/zshconfig_fedora.conf" "${TARGET_USER}@${TARGET_IP}:/tmp/zshconfig_fedora.conf"
if [[ $DEPLOY_NVIM == [yY] ]]; then
    scp $SCP_OPTS -P "$TARGET_PORT" "$DIR/../nvimconfig.lua" "${TARGET_USER}@${TARGET_IP}:/tmp/nvimconfig.lua"
else
    # Clear any stale copy from a previous run so the payload doesn't apply it
    ssh -p "$TARGET_PORT" "${TARGET_USER}@${TARGET_IP}" "rm -f /tmp/nvimconfig.lua"
fi
if [[ $DEPLOY_GIT == [yY] ]]; then
    scp $SCP_OPTS -P "$TARGET_PORT" "$DIR/../gitconfig.conf"     "${TARGET_USER}@${TARGET_IP}:/tmp/gitconfig.conf"
else
    ssh -p "$TARGET_PORT" "${TARGET_USER}@${TARGET_IP}" "rm -f /tmp/gitconfig.conf"
fi
# Always clear any stale bridge from a previous run; recopy the whole folder on opt-in.
ssh -p "$TARGET_PORT" "${TARGET_USER}@${TARGET_IP}" "rm -rf /tmp/tls_bridge"
if [[ $DEPLOY_TLS == [yY] ]]; then
    scp $SCP_OPTS -r -P "$TARGET_PORT" "$DIR/../python_exploits/tls" "${TARGET_USER}@${TARGET_IP}:/tmp/tls_bridge"
fi
scp $SCP_OPTS -P "$TARGET_PORT" /tmp/vulnbox_payload.sh      "${TARGET_USER}@${TARGET_IP}:/tmp/setup.sh"

echo -e "\n=== 3. RUNNING REMOTE SETUP ==="
echo "Note: the remote setup runs sudo on the TARGET. If asked for a password, enter the"
echo "      password for ${TARGET_USER}@${TARGET_IP} (the vulnbox) — NOT your local machine."
ssh -p "$TARGET_PORT" -t "${TARGET_USER}@${TARGET_IP}" "DO_BACKUP='$DO_BACKUP' BACKUP_PATHS='$BACKUP_PATHS' DEV_REPO_URL='$DEV_REPO_URL' DEV_REPO_NAME='$DEV_REPO_NAME' DEV_REPO_BRANCH='$DEV_REPO_BRANCH' bash /tmp/setup.sh && rm /tmp/setup.sh"

if [[ $DO_BACKUP == y ]]; then
    echo -e "\n=== 4. PULLING BACKUP ==="
    # Don't clobber an existing archive — fall back to _1, _2, … if the name is taken.
    BACKUP_FILE="${BACKUP_DEST}/backup_from_${TARGET_IP}.zip"
    if [[ -e "$BACKUP_FILE" ]]; then
        _i=1
        while [[ -e "${BACKUP_DEST}/backup_from_${TARGET_IP}_${_i}.zip" ]]; do _i=$((_i + 1)); done
        BACKUP_FILE="${BACKUP_DEST}/backup_from_${TARGET_IP}_${_i}.zip"
    fi
    echo "Moving backup.zip to ${BACKUP_FILE}"
    scp $SCP_OPTS -P "$TARGET_PORT" "${TARGET_USER}@${TARGET_IP}:~/backup.zip" "$BACKUP_FILE"
else
    echo -e "\n=== 4. BACKUP SKIPPED ==="
fi

echo -e "\n=== 5. LOGGING IN ==="
ssh -p "$TARGET_PORT" -t "${TARGET_USER}@${TARGET_IP}" "exec zsh"
