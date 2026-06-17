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

# ── 5. GENERATE PAYLOAD ───────────────────────────────────────────────────────
echo -e "\n=== 2. DEPLOYING PAYLOAD ==="

# The box may already have a Neovim config — only deploy ours if asked.
read -rp "Deploy the Neovim config to ~/.config/nvim/init.lua on the target? (y/N) " DEPLOY_NVIM

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

# Install packages via yay (handles both official and AUR)
yay -Syu --noconfirm --needed \
    zip zsh nano git curl fastfetch lsd tty-clock cmatrix \
    zsh-syntax-highlighting zsh-autosuggestions openssh

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

# Backup home directory (exclude the zip itself using full-path glob)
rm -f ~/backup.zip
zip -r ~/backup.zip ~ -x "$HOME/backup.zip"

echo "Deployment complete."
PAYLOAD_EOF

# ── 5. TRANSFER & EXECUTE ─────────────────────────────────────────────────────
scp -P "$TARGET_PORT" "$DIR/zshconfig_arch.conf"  "${TARGET_USER}@${TARGET_IP}:/tmp/zshconfig_arch.conf"
if [[ $DEPLOY_NVIM == [yY] ]]; then
    scp -P "$TARGET_PORT" "$DIR/../nvimconfig.lua" "${TARGET_USER}@${TARGET_IP}:/tmp/nvimconfig.lua"
else
    # Clear any stale copy from a previous run so the payload doesn't apply it
    ssh -p "$TARGET_PORT" "${TARGET_USER}@${TARGET_IP}" "rm -f /tmp/nvimconfig.lua"
fi
scp -P "$TARGET_PORT" /tmp/vulnbox_payload.sh     "${TARGET_USER}@${TARGET_IP}:/tmp/setup.sh"

echo -e "\n=== 3. RUNNING REMOTE SETUP ==="
echo "Note: the remote setup runs sudo on the TARGET. If asked for a password, enter the"
echo "      password for ${TARGET_USER}@${TARGET_IP} (the vulnbox) — NOT your local machine."
ssh -p "$TARGET_PORT" -t "${TARGET_USER}@${TARGET_IP}" "bash /tmp/setup.sh && rm /tmp/setup.sh"

echo -e "\n=== 4. PULLING BACKUP ==="
scp -P "$TARGET_PORT" "${TARGET_USER}@${TARGET_IP}:~/backup.zip" "$DIR/backup_from_${TARGET_IP}.zip"

echo -e "\n=== 5. LOGGING IN ==="
ssh -p "$TARGET_PORT" -t "${TARGET_USER}@${TARGET_IP}" "exec zsh"
