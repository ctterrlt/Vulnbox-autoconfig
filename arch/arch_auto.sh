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

# ── 2. INPUT ──────────────────────────────────────────────────────────────────
echo -e "\n=== LOCAL NETWORK INTERFACES ==="
ip -br addr

echo -e "\n=== TARGET CONFIGURATION ==="
read -rp "Enter target remote IP: " TARGET_IP
read -rp "Enter target remote username: " TARGET_USER

# ── 3. SECURE ACCESS ──────────────────────────────────────────────────────────
echo -e "\n=== 1. SECURING ACCESS ==="

# Generate key only if missing
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    echo "No SSH key found. Generating a new passwordless Ed25519 key..."
    ssh-keygen -t ed25519 -N "" -f "$HOME/.ssh/id_ed25519"
else
    echo "Existing SSH key found at ~/.ssh/id_ed25519. Skipping generation."
fi

# Copy key — fall back to manual method if ssh-copy-id fails (e.g. no sshpass)
echo "Copying key to ${TARGET_USER}@${TARGET_IP}..."
if ! ssh -o BatchMode=yes -o ConnectTimeout=3 "${TARGET_USER}@${TARGET_IP}" true 2>/dev/null; then
    ssh-copy-id -i "$HOME/.ssh/id_ed25519.pub" "${TARGET_USER}@${TARGET_IP}" || \
    cat "$HOME/.ssh/id_ed25519.pub" | ssh "${TARGET_USER}@${TARGET_IP}" \
        "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
else
    echo "Key already accepted. Skipping ssh-copy-id."
fi

# ── 4. GENERATE PAYLOAD ───────────────────────────────────────────────────────
echo -e "\n=== 2. DEPLOYING PAYLOAD ==="

cat << 'PAYLOAD_EOF' > /tmp/vulnbox_payload.sh
#!/bin/bash
set -euo pipefail

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

# Backup home directory (exclude the zip itself using full-path glob)
rm -f ~/backup.zip
zip -r ~/backup.zip ~ -x "$HOME/backup.zip"

echo "Deployment complete."
PAYLOAD_EOF

# ── 5. TRANSFER & EXECUTE ─────────────────────────────────────────────────────
scp "$DIR/zshconfig_arch.conf"  "${TARGET_USER}@${TARGET_IP}:/tmp/zshconfig_arch.conf"
scp /tmp/vulnbox_payload.sh     "${TARGET_USER}@${TARGET_IP}:/tmp/setup.sh"

echo "Running remote setup..."
ssh "${TARGET_USER}@${TARGET_IP}" "bash /tmp/setup.sh && rm /tmp/setup.sh"

echo "Pulling backup to local machine..."
scp "${TARGET_USER}@${TARGET_IP}:~/backup.zip" "$DIR/backup_from_${TARGET_IP}.zip"

echo "Deployment complete. Logging you in..."
ssh -t "${TARGET_USER}@${TARGET_IP}" "exec zsh"
