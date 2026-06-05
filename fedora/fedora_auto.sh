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

cat << 'PAYLOAD_EOF' > /tmp/vulnbox_payload.sh
#!/bin/bash
set -euo pipefail

# Install packages
# Note: fastfetch, lsd, tty-clock may not be in default Fedora repos.
# zsh-syntax-highlighting and zsh-autosuggestions are better managed
# via Oh-My-Zsh plugins on Fedora — the conf handles this already.
sudo dnf install -y \
    zip zsh nano git curl \
    neofetch lsd tty-clock cmatrix \
    openssh-server

# Install Oh-My-Zsh (non-interactive, skip if already present)
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Change default shell to zsh
sudo chsh -s "$(which zsh)" "$USER"

# Apply config
mv /tmp/zshconfig_fedora.conf ~/.zshrc

# Backup home directory (exclude the zip itself using full path)
rm -f ~/backup.zip
zip -r ~/backup.zip ~ -x "$HOME/backup.zip"

echo "Deployment complete."
PAYLOAD_EOF

# ── 5. TRANSFER & EXECUTE ─────────────────────────────────────────────────────
scp -P "$TARGET_PORT" "$DIR/zshconfig_fedora.conf" "${TARGET_USER}@${TARGET_IP}:/tmp/zshconfig_fedora.conf"
scp -P "$TARGET_PORT" /tmp/vulnbox_payload.sh      "${TARGET_USER}@${TARGET_IP}:/tmp/setup.sh"

echo -e "\n=== 3. RUNNING REMOTE SETUP ==="
ssh -p "$TARGET_PORT" "${TARGET_USER}@${TARGET_IP}" "bash /tmp/setup.sh && rm /tmp/setup.sh"

echo -e "\n=== 4. PULLING BACKUP ==="
scp -P "$TARGET_PORT" "${TARGET_USER}@${TARGET_IP}:~/backup.zip" "$DIR/backup_from_${TARGET_IP}.zip"

echo -e "\n=== 5. LOGGING IN ==="
ssh -p "$TARGET_PORT" -t "${TARGET_USER}@${TARGET_IP}" "exec zsh"
