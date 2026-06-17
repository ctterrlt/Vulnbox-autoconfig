#!/bin/bash
# Shared SSH setup — sourced by each distro's auto.sh.
# Sets: TARGET_IP, TARGET_USER, TARGET_PORT, HOST_ALIAS

# ── INPUT ─────────────────────────────────────────────────────────────────────
echo -e "\n=== LOCAL NETWORK INTERFACES ==="
ip -br addr

SSH_CONF="$HOME/.ssh/config"

# Offer to reuse a host already in ~/.ssh/config instead of retyping everything.
# Concrete host aliases only (skip wildcard patterns); values are resolved with
# `ssh -G` so we get the effective HostName/User/Port.
REUSED_HOST=0
if [[ -f "$SSH_CONF" ]]; then
    mapfile -t SSH_HOSTS < <(awk 'tolower($1)=="host"{for(i=2;i<=NF;i++) if($i !~ /[*?]/) print $i}' "$SSH_CONF")
    if (( ${#SSH_HOSTS[@]} > 0 )); then
        echo -e "\n=== EXISTING SSH HOSTS ==="
        for i in "${!SSH_HOSTS[@]}"; do
            printf "  %d) %s\n" "$((i + 1))" "${SSH_HOSTS[$i]}"
        done
        read -rp "Reuse one of these? number, or Enter to set up a NEW target: " HOST_PICK
        if [[ "$HOST_PICK" =~ ^[0-9]+$ ]] && (( HOST_PICK >= 1 && HOST_PICK <= ${#SSH_HOSTS[@]} )); then
            HOST_ALIAS="${SSH_HOSTS[$((HOST_PICK - 1))]}"
            TARGET_IP="$(ssh -G "$HOST_ALIAS" 2>/dev/null | awk '/^hostname /{print $2; exit}')"
            TARGET_USER="$(ssh -G "$HOST_ALIAS" 2>/dev/null | awk '/^user /{print $2; exit}')"
            TARGET_PORT="$(ssh -G "$HOST_ALIAS" 2>/dev/null | awk '/^port /{print $2; exit}')"
            TARGET_PORT=${TARGET_PORT:-22}
            if [[ -z "$TARGET_IP" || -z "$TARGET_USER" ]]; then
                # Host matched but has no usable HostName/User in the config.
                echo "[!] No match: '${HOST_ALIAS}' has no HostName/User defined in ~/.ssh/config."
                read -rp "    [a]bort, or [m]anually enter IP/user? (a/m) [m]: " NOMATCH
                if [[ "$NOMATCH" == [aA] ]]; then echo "Aborted."; exit 1; fi
            else
                REUSED_HOST=1
                echo "[OK] Reusing '${HOST_ALIAS}' -> ${TARGET_USER}@${TARGET_IP}:${TARGET_PORT}"
            fi
        elif [[ -n "$HOST_PICK" ]]; then
            # Non-empty input that isn't a valid list number.
            echo "[!] No match: '${HOST_PICK}' is not one of the listed hosts."
            read -rp "    [a]bort, or [m]anually enter IP/user? (a/m) [m]: " NOMATCH
            if [[ "$NOMATCH" == [aA] ]]; then echo "Aborted."; exit 1; fi
        fi
    fi
fi

if [[ "$REUSED_HOST" != "1" ]]; then
    echo -e "\n=== TARGET CONFIGURATION ==="
    read -rp "Enter target remote IP: " TARGET_IP
    read -rp "Enter target remote username: " TARGET_USER
    read -rp "Enter target SSH port [22]: " TARGET_PORT
    TARGET_PORT=${TARGET_PORT:-22}
    read -rp "Enter a name for this host in ~/.ssh/config [${TARGET_IP}]: " HOST_ALIAS
    HOST_ALIAS=${HOST_ALIAS:-$TARGET_IP}
fi

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

    # ~/.ssh/id_ed25519.pub may hold several public keys. Let the operator pick
    # which one(s) to push per run instead of spraying all of them. We never
    # modify the .pub file — selected keys go into a temp file we hand to
    # ssh-copy-id (which itself skips any key already present on the target).
    PUBFILE="$HOME/.ssh/id_ed25519.pub"
    GENUINE_KEY="$(ssh-keygen -y -f "$HOME/.ssh/id_ed25519" | awk '{print $1" "$2}')"
    mapfile -t KEY_LINES < <(grep -vE '^[[:space:]]*$' "$PUBFILE")

    echo -e "\n=== SELECT KEY(S) TO COPY ==="
    GENUINE_IDX=1
    for i in "${!KEY_LINES[@]}"; do
        body="$(awk '{print $1" "$2}' <<< "${KEY_LINES[$i]}")"
        comment="$(awk '{print $3}' <<< "${KEY_LINES[$i]}")"
        mark=""
        if [[ "$body" == "$GENUINE_KEY" ]]; then
            mark="  <- your login key (matches id_ed25519)"
            GENUINE_IDX=$((i + 1))
        fi
        printf "  %d) %s%s\n" "$((i + 1))" "${comment:-<no comment>}" "$mark"
    done
    read -rp "Which key(s) to copy? space-separated numbers, or 'all' [${GENUINE_IDX}]: " KEY_SEL
    KEY_SEL=${KEY_SEL:-$GENUINE_IDX}

    SEL_PUB="$(mktemp)"
    trap 'rm -f "$SEL_PUB"' EXIT
    if [[ "$KEY_SEL" == "all" ]]; then
        printf '%s\n' "${KEY_LINES[@]}" > "$SEL_PUB"
    else
        for n in $KEY_SEL; do
            if [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#KEY_LINES[@]} )); then
                printf '%s\n' "${KEY_LINES[$((n - 1))]}" >> "$SEL_PUB"
            fi
        done
    fi

    if [[ ! -s "$SEL_PUB" ]]; then
        echo "[ERR] No valid key selected — skipping key copy."
    else
        if ! grep -qF "$GENUINE_KEY" "$SEL_PUB"; then
            echo "[WARN] Your own login key was not selected — later SSH steps may prompt for a password."
        fi
        echo "Copying selected key(s) to ${TARGET_USER}@${TARGET_IP}..."
        echo "(If prompted for a password here, it's the REMOTE login password of ${TARGET_USER}@${TARGET_IP} — not your local machine.)"
        if ! ssh-copy-id -p "$TARGET_PORT" -i "$SEL_PUB" "${TARGET_USER}@${TARGET_IP}"; then
            cat "$SEL_PUB" | ssh -p "$TARGET_PORT" "${TARGET_USER}@${TARGET_IP}" \
                "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
        fi
    fi
fi
