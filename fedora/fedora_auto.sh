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

# ── 2. INPUT ──────────────────────────────────────────────────────────────────
echo -e "\n=== LOCAL NETWORK INTERFACES ==="
ip -br addr

echo -e "\n=== TARGET CONFIGURATION ==="
read -rp "Enter target remote IP: " TARGET_IP
read -rp "Enter target remote username: " TARGET_USER
read -rp "Enter target SSH port [22]: " TARGET_PORT
TARGET_PORT=${TARGET_PORT:-22}
read -rp "Enter a name for this host in ~/.ssh/config [${TARGET_IP}]: " HOST_ALIAS
HOST_ALIAS=${HOST_ALIAS:-$TARGET_IP}

# ── 3. UPDATE LOCAL SSH CONFIG ────────────────────────────────────────────────
echo -e "\n=== SSH CONFIG ==="
mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
SSH_CONF="$HOME/.ssh/config"
touch "$SSH_CONF"
if ! grep -q "^Host ${HOST_ALIAS}$" "$SSH_CONF" 2>/dev/null; then
    printf '\nHost %s\n    HostName %s\n    User %s\n    Port %s\n    IdentityFile ~/.ssh/id_ed25519\n' \
        "$HOST_ALIAS" "$TARGET_IP" "$TARGET_USER" "$TARGET_PORT" >> "$SSH_CONF"
    echo "[OK] Added '${HOST_ALIAS}' -> ${TARGET_IP} to ~/.ssh/config"
else
    echo "[OK] '${HOST_ALIAS}' already in ~/.ssh/config — skipping."
fi

# ── 4. SECURE ACCESS ──────────────────────────────────────────────────────────
echo -e "\n=== 1. SECURING ACCESS ==="

# Generate key only if missing
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    echo "No SSH key found. Generating a new passwordless Ed25519 key..."
    ssh-keygen -t ed25519 -N "" -f "$HOME/.ssh/id_ed25519"
else
    echo "Existing SSH key found at ~/.ssh/id_ed25519. Skipping generation."
fi

# Copy key — skip if already accepted, fall back to manual method if needed
echo "Copying key to ${TARGET_USER}@${TARGET_IP}..."
if ! ssh -p "$TARGET_PORT" -o BatchMode=yes -o ConnectTimeout=3 "${TARGET_USER}@${TARGET_IP}" true 2>/dev/null; then
    ssh-copy-id -p "$TARGET_PORT" -i "$HOME/.ssh/id_ed25519.pub" "${TARGET_USER}@${TARGET_IP}" || \
    cat "$HOME/.ssh/id_ed25519.pub" | ssh -p "$TARGET_PORT" "${TARGET_USER}@${TARGET_IP}" \
        "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
else
    echo "Key already accepted. Skipping ssh-copy-id."
fi

# ── 4. GENERATE PAYLOAD ───────────────────────────────────────────────────────
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

echo "Running remote setup..."
ssh -p "$TARGET_PORT" "${TARGET_USER}@${TARGET_IP}" "bash /tmp/setup.sh && rm /tmp/setup.sh"

echo "Pulling backup to local machine..."
scp -P "$TARGET_PORT" "${TARGET_USER}@${TARGET_IP}:~/backup.zip" "$DIR/backup_from_${TARGET_IP}.zip"

echo "Deployment complete. Logging you in..."
ssh -p "$TARGET_PORT" -t "${TARGET_USER}@${TARGET_IP}" "exec zsh"
