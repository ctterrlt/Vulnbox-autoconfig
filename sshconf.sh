#!/bin/bash
# Shared SSH setup — sourced by each distro's auto.sh.
# Sets: TARGET_IP, TARGET_USER, TARGET_PORT, HOST_ALIAS

# ── INPUT ─────────────────────────────────────────────────────────────────────
echo -e "\n=== LOCAL NETWORK INTERFACES ==="
ip -br addr

echo -e "\n=== TARGET CONFIGURATION ==="
read -rp "Enter target remote IP: " TARGET_IP
read -rp "Enter target remote username: " TARGET_USER
read -rp "Enter target SSH port [22]: " TARGET_PORT
TARGET_PORT=${TARGET_PORT:-22}
read -rp "Enter a name for this host in ~/.ssh/config [${TARGET_IP}]: " HOST_ALIAS
HOST_ALIAS=${HOST_ALIAS:-$TARGET_IP}

# ── UPDATE LOCAL SSH CONFIG ───────────────────────────────────────────────────
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

# ── SECURE ACCESS ─────────────────────────────────────────────────────────────
# Set SKIP_SSH=1 to skip key-gen and key-copy (e.g. key already deployed).
if [[ "${SKIP_SSH:-0}" != "1" ]]; then
    echo -e "\n=== 1. SECURING ACCESS ==="

    if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
        echo "No SSH key found. Generating a new passwordless Ed25519 key..."
        ssh-keygen -t ed25519 -N "" -f "$HOME/.ssh/id_ed25519"
    else
        echo "Existing SSH key found at ~/.ssh/id_ed25519. Skipping generation."
    fi

    echo "Copying key to ${TARGET_USER}@${TARGET_IP}..."
    if ! ssh -p "$TARGET_PORT" -o BatchMode=yes -o ConnectTimeout=3 "${TARGET_USER}@${TARGET_IP}" true 2>/dev/null; then
        ssh-copy-id -p "$TARGET_PORT" -i "$HOME/.ssh/id_ed25519.pub" "${TARGET_USER}@${TARGET_IP}" || \
        cat "$HOME/.ssh/id_ed25519.pub" | ssh -p "$TARGET_PORT" "${TARGET_USER}@${TARGET_IP}" \
            "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
    else
        echo "Key already accepted. Skipping ssh-copy-id."
    fi
fi
