#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Re-push the zsh config to the remote target without full redeployment.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$DIR/zshconfig_debian_ubuntu.conf"
BASH_CONF="$DIR/bashconfig_debian_ubuntu.conf"

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
if [ ! -f "$BASH_CONF" ] || [ ! -f "$DIR/../install_bash_config.sh" ]; then
    echo "Error: Bash config or installer is missing."
    exit 1
fi

# ── Input ─────────────────────────────────────────────────────────────────────
read -rp "Enter target remote IP: " TARGET_IP
read -rp "Enter target remote username: " TARGET_USER
read -rp "Enter target SSH port [22]: " TARGET_PORT
TARGET_PORT=${TARGET_PORT:-22}
if ! [[ "$TARGET_PORT" =~ ^[0-9]{1,5}$ ]] || \
   (( 10#$TARGET_PORT < 1 || 10#$TARGET_PORT > 65535 )); then
    echo "Error: SSH port must be a number from 1 to 65535." >&2
    exit 1
fi

# ── Transfer & apply ──────────────────────────────────────────────────────────
echo "Uploading config to ${TARGET_USER}@${TARGET_IP}..."
scp -O -P "$TARGET_PORT" "$CONF" "${TARGET_USER}@${TARGET_IP}:/tmp/zshconfig_debian_ubuntu.conf"
scp -O -P "$TARGET_PORT" "$BASH_CONF" "${TARGET_USER}@${TARGET_IP}:/tmp/bashconfig_debian_ubuntu.conf"
scp -O -P "$TARGET_PORT" "$DIR/../install_bash_config.sh" "${TARGET_USER}@${TARGET_IP}:/tmp/install_bash_config.sh"
ssh -p "$TARGET_PORT" "${TARGET_USER}@${TARGET_IP}" 'if [[ -e "$HOME/.zshrc" || -L "$HOME/.zshrc" ]]; then cp -a "$HOME/.zshrc" "$HOME/.zshrc.vulnbox-backup.$(date +%Y%m%d%H%M%S)"; fi && mv /tmp/zshconfig_debian_ubuntu.conf "$HOME/.zshrc" && bash /tmp/install_bash_config.sh /tmp/bashconfig_debian_ubuntu.conf && rm -f /tmp/install_bash_config.sh && echo "Zsh and Bash configs updated successfully."'
