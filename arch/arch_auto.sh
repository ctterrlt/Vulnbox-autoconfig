#!/bin/bash
# VULNBOX AUTO-DEPLOYMENT SCRIPT (ARCH)
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

# ── 5. LOCAL DEPS + DEPLOYMENT PROMPTS (shared across all distros) ────────────
# The local Python-deps install and every "what to deploy" prompt live in one
# shared file so the three <distro>_auto.sh stay in sync (only the package install
# / payload below is per-distro). It sets DEPLOY_NVIM/_GIT/_TLS, DEV_REPO_*,
# DO_BACKUP, BACKUP_PATHS and BACKUP_DEST for the payload.
. "$DIR/../deployconf.sh"

cat << 'PAYLOAD_EOF' > /tmp/vulnbox_payload.sh
#!/bin/bash
set -euo pipefail

# Prime sudo once up front so the prompt is clear (not buried in package output)
# and cached for the rest of the run. This runs ON the vulnbox via `ssh -t`, so
# the password requested is the REMOTE box's, NOT your local machine's.
echo ">>> sudo below wants the password of $(whoami)@$(hostname) — the REMOTE vulnbox, not your local PC."
sudo -v

# Bootstrap yay if not present
if ! command -v yay &>/dev/null; then
    sudo pacman -Sy --noconfirm --needed base-devel git
    tmpdir=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
    if [[ $EUID -eq 0 ]]; then
        useradd -M -s /bin/bash _aurbuild 2>/dev/null || true
        chown -R _aurbuild: "$tmpdir/yay"
        echo "_aurbuild ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/_aurbuild
        sudo -u _aurbuild bash -c "cd '$tmpdir/yay' && makepkg -si --noconfirm"
        rm -f /etc/sudoers.d/_aurbuild
        userdel _aurbuild 2>/dev/null || true
    else
        (cd "$tmpdir/yay" && makepkg -si --noconfirm)
    fi
    rm -rf "$tmpdir"
fi

# Install packages via yay (handles both official and AUR). Core first, then the
# cosmetic extras best-effort, so a package that's missing or renamed in the repos
# can't abort the whole deploy.
# php: runtime for the PHP-based web exploits (python_exploits/web/ccalendar_*).
yay -Syu --noconfirm --needed \
    zip zsh nano git curl zsh-syntax-highlighting zsh-autosuggestions openssh php
for _pkg in fastfetch lsd tty-clock cmatrix; do
    yay -S --noconfirm --needed "$_pkg" || echo "  (skipped $_pkg — not available in repos)"
done

# Install Oh-My-Zsh (non-interactive, skip if already present)
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Change default shell to zsh
sudo chsh -s "$(which zsh)" "$USER"

# Apply config
mv /tmp/zshconfig_arch.conf ~/.zshrc

# Apply Neovim config (only if it was transferred — user opted in)
if [ -f /tmp/nvimconfig.lua ]; then
    # Install neovim only if missing or outdated (--needed skips up-to-date pkgs)
    yay -S --noconfirm --needed neovim
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

# Apply nano config (only if transferred — user opted in). Per-user ~/.nanorc needs
# no root and is read after /etc/nanorc, so it overrides without clobbering it.
if [ -f /tmp/nanorc ]; then
    mv /tmp/nanorc ~/.nanorc
    echo "nano config applied to ~/.nanorc."
fi

# Apply Konsole config (only if transferred — user opted in). We don't install
# konsole (vulnboxes are usually headless) — just drop the files so they're ready
# if konsole is/gets installed. konsolerc -> ~/.config/, profile -> ~/.local/share/.
if [ -f /tmp/konsolerc ]; then
    mkdir -p ~/.config
    mv /tmp/konsolerc ~/.config/konsolerc
    if [ -f /tmp/konsole.profile ]; then
        mkdir -p ~/.local/share/konsole
        mv /tmp/konsole.profile ~/.local/share/konsole/Vulnbox.profile
    fi
    echo "Konsole config applied (~/.config/konsolerc + Vulnbox profile)."
fi

# Give the box's root the SAME zsh setup (only if root_shell.sh was sent — opt-in,
# default yes). Skipped when deploying AS root (root is then the login user we already
# configured). root_shell.sh: chsh root -> zsh, install Oh-My-Zsh for root, and link
# /root/.zshrc to this user's ~/.zshrc — so `sudo su` / `su -` on the box keep your
# config. The deploy still finishes by logging you in as your normal user, so you're
# never left in a root shell.
if [ -f /tmp/root_shell.sh ]; then
    if [ "$(id -u)" -ne 0 ]; then
        sudo bash /tmp/root_shell.sh "$USER" || echo "  (root shell setup skipped/failed — continuing)"
    else
        echo "Deployed as root — root already configured; skipping root_shell.sh."
    fi
    rm -f /tmp/root_shell.sh
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
    # Git init each path on demand — the .git data rides inside the backup so
    # the pulled archive is a ready-to-use repo from the start. Idempotent:
    # skips dirs that already have .git, adds .gitignore if there isn't one.
    if [ "${DO_GIT_INIT_REMOTE:-n}" = "y" ]; then
        for _p in "${_backup_paths[@]}"; do
            if [ -d "$_p" ]; then
                if [ ! -d "$_p/.git" ]; then
                    git -C "$_p" init -q 2>/dev/null \
                        && echo "  -> git init'd $_p" \
                        || echo "  (git init skipped for $_p)"
                else
                    echo "  -> $_p already has .git (skipping init)"
                fi
                if [ ! -f "$_p/.gitignore" ]; then
                    printf '%s\n' \
                        '*.pyc' '__pycache__/' '.venv/' '.env' \
                        '*.zip' '*.tar.gz' '*.log' '.DS_Store' \
                        > "$_p/.gitignore" 2>/dev/null || true
                    echo "  -> added .gitignore to $_p"
                fi
            fi
        done
    fi
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
scp $SCP_OPTS -P "$TARGET_PORT" "$DIR/zshconfig_arch.conf"  "${TARGET_USER}@${TARGET_IP}:/tmp/zshconfig_arch.conf"
if [[ $DEPLOY_NVIM == [yY] ]]; then
    scp $SCP_OPTS -P "$TARGET_PORT" "$DIR/../nvimconfig.lua" "${TARGET_USER}@${TARGET_IP}:/tmp/nvimconfig.lua"
else
    # Clear any stale copy from a previous run so the payload doesn't apply it
    ssh -p "$TARGET_PORT" "${TARGET_USER}@${TARGET_IP}" "rm -f /tmp/nvimconfig.lua"
fi
if [[ $DEPLOY_GIT == [yY] ]]; then
    scp $SCP_OPTS -P "$TARGET_PORT" "$DIR/../gitconfig.conf" "${TARGET_USER}@${TARGET_IP}:/tmp/gitconfig.conf"
else
    ssh -p "$TARGET_PORT" "${TARGET_USER}@${TARGET_IP}" "rm -f /tmp/gitconfig.conf"
fi
if [[ $DEPLOY_NANO == [yY] ]]; then
    scp $SCP_OPTS -P "$TARGET_PORT" "$DIR/../nanorc"         "${TARGET_USER}@${TARGET_IP}:/tmp/nanorc"
else
    ssh -p "$TARGET_PORT" "${TARGET_USER}@${TARGET_IP}" "rm -f /tmp/nanorc"
fi
if [[ $DEPLOY_KONSOLE == [yY] ]]; then
    scp $SCP_OPTS -P "$TARGET_PORT" "$DIR/../konsolerc"       "${TARGET_USER}@${TARGET_IP}:/tmp/konsolerc"
    scp $SCP_OPTS -P "$TARGET_PORT" "$DIR/../konsole.profile" "${TARGET_USER}@${TARGET_IP}:/tmp/konsole.profile"
else
    ssh -p "$TARGET_PORT" "${TARGET_USER}@${TARGET_IP}" "rm -f /tmp/konsolerc /tmp/konsole.profile"
fi
if [[ "${DEPLOY_ROOTSHELL:-Y}" != [nN] ]]; then
    scp $SCP_OPTS -P "$TARGET_PORT" "$DIR/../root_shell.sh"   "${TARGET_USER}@${TARGET_IP}:/tmp/root_shell.sh"
else
    ssh -p "$TARGET_PORT" "${TARGET_USER}@${TARGET_IP}" "rm -f /tmp/root_shell.sh"
fi
# Always clear any stale bridge from a previous run; recopy the whole folder on opt-in.
ssh -p "$TARGET_PORT" "${TARGET_USER}@${TARGET_IP}" "rm -rf /tmp/tls_bridge"
if [[ $DEPLOY_TLS == [yY] ]]; then
    scp $SCP_OPTS -r -P "$TARGET_PORT" "$DIR/../python_exploits/tls" "${TARGET_USER}@${TARGET_IP}:/tmp/tls_bridge"
fi
scp $SCP_OPTS -P "$TARGET_PORT" /tmp/vulnbox_payload.sh     "${TARGET_USER}@${TARGET_IP}:/tmp/setup.sh"

echo -e "\n=== 3. RUNNING REMOTE SETUP ==="
echo "Note: the remote setup runs sudo on the TARGET. If asked for a password, enter the"
echo "      password for ${TARGET_USER}@${TARGET_IP} (the vulnbox) — NOT your local machine."
ssh -p "$TARGET_PORT" -t "${TARGET_USER}@${TARGET_IP}" "DO_BACKUP='$DO_BACKUP' BACKUP_PATHS='$BACKUP_PATHS' DO_GIT_INIT_REMOTE='$DO_GIT_INIT_REMOTE' DEV_REPO_URL='$DEV_REPO_URL' DEV_REPO_NAME='$DEV_REPO_NAME' DEV_REPO_BRANCH='$DEV_REPO_BRANCH' bash /tmp/setup.sh && rm /tmp/setup.sh"

BACKUP_FILE=""
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

post_backup_processing "$BACKUP_FILE"

echo "$TARGET_USER:$TARGET_IP:$TARGET_PORT" > /tmp/.vulnbox_target
