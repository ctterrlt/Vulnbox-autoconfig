#!/bin/bash
# Re-push the zsh config to the remote target without full redeployment.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$DIR/zshconfig_fedora.conf"

# ── Safety guard ──────────────────────────────────────────────────────────────
if [ ! -f /.dockerenv ] && \
   ! grep -qE '(docker|containerd|lxc)' /proc/1/cgroup 2>/dev/null && \
   [ ! -f /tmp/is_vulnbox ]; then
    echo "!!! DANGER !!! This pushes config to a REMOTE target."
    read -rp "Proceed anyway? (y/N) " confirm
    [[ $confirm != [yY]* ]] && exit 1
fi

# ── Verify config exists ──────────────────────────────────────────────────────
if [ ! -f "$CONF" ]; then
    echo "Error: config file not found at $CONF"
    exit 1
fi

# ── Input ─────────────────────────────────────────────────────────────────────
read -rp "Enter target remote IP: " TARGET_IP
read -rp "Enter target remote username: " TARGET_USER

# ── Transfer & apply ──────────────────────────────────────────────────────────
echo "Uploading config to ${TARGET_USER}@${TARGET_IP}..."
scp -O "$CONF" "${TARGET_USER}@${TARGET_IP}:/tmp/zshconfig_fedora.conf"
ssh "${TARGET_USER}@${TARGET_IP}" "mv /tmp/zshconfig_fedora.conf ~/.zshrc && echo 'Config updated successfully.'"
