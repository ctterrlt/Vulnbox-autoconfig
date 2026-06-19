#!/bin/bash
# Shared SSH setup — sourced by each distro's auto.sh.
# Sets: TARGET_IP, TARGET_USER, TARGET_PORT, HOST_ALIAS

# Shared selection helper (review_selection: list selected → confirm/add/remove).
_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$_SELF_DIR/selectlib.sh"

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
                echo "[OK] Selected '${HOST_ALIAS}' -> ${TARGET_USER}@${TARGET_IP}:${TARGET_PORT}"
                read -rp "    Use this host? [Y]es / [n]o (enter target manually): " HOST_OK
                if [[ "$HOST_OK" == [nN] ]]; then
                    echo "    -> entering target manually."
                else
                    REUSED_HOST=1
                fi
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

if [[ "$REUSED_HOST" == "1" ]]; then
    # Picked an existing host on purpose — leave its config entry untouched.
    echo "[OK] Reusing existing '${HOST_ALIAS}' from ~/.ssh/config."
else
    # New target: write the entry. If the alias already exists, the old code silently
    # skipped (so a reused alias kept its stale IP/user/port) — now we ask to overwrite.
    _write_host=1
    if grep -qiE "^[[:space:]]*Host[[:space:]]+${HOST_ALIAS}([[:space:]]|\$)" "$SSH_CONF" 2>/dev/null; then
        read -rp "Host '${HOST_ALIAS}' already exists in ~/.ssh/config — overwrite it? [y/N]: " _ovw
        if [[ "${_ovw:-}" == [yY] ]]; then
            # Drop the existing 'Host <alias>' block (its Host line + following lines,
            # up to the next Host entry), then append the fresh one below.
            _tmp="$(mktemp)"
            awk -v alias="$HOST_ALIAS" '
                tolower($1)=="host" {
                    skip=0
                    for (i=2;i<=NF;i++) if ($i==alias) skip=1
                    if (skip) next
                }
                skip!=1 { print }
            ' "$SSH_CONF" > "$_tmp" && cat "$_tmp" > "$SSH_CONF"
            rm -f "$_tmp"
            echo "[OK] Replacing old '${HOST_ALIAS}' entry with ${TARGET_USER}@${TARGET_IP}:${TARGET_PORT}."
        else
            _write_host=0
            echo "[OK] Keeping the existing '${HOST_ALIAS}' entry — ~/.ssh/config not modified."
        fi
    fi
    if [[ "$_write_host" == "1" ]]; then
        printf '\nHost %s\n    HostName %s\n    User %s\n    Port %s\n    IdentityFile ~/.ssh/id_ed25519\n' \
            "$HOST_ALIAS" "$TARGET_IP" "$TARGET_USER" "$TARGET_PORT" >> "$SSH_CONF"
        echo "[OK] Wrote '${HOST_ALIAS}' -> ${TARGET_IP} to ~/.ssh/config"
    fi
fi

# ── SCP TRANSFER PROTOCOL ─────────────────────────────────────────────────────
# Modern scp (OpenSSH 9+) uses the SFTP subsystem, which fails with
# "subsystem request failed on channel 0" on boxes whose sshd lacks it (e.g.
# after an openssh upgrade mid-deploy). Legacy mode (scp -O) avoids that.
# SCP_OPTS is consumed unquoted by every scp call in the distro deploy scripts.
echo -e "\n=== SCP PROTOCOL ==="
echo "Legacy mode (scp -O) is the most compatible — recommended for vulnboxes."
read -rp "Use legacy scp protocol (-O)? [Y]es (Enter) / [n]o (modern SFTP): " _scp_legacy
if [[ "$_scp_legacy" == [nN] ]]; then
    SCP_OPTS=""
    echo "[OK] Using modern SFTP-based scp."
else
    SCP_OPTS="-O"
    echo "[OK] Using legacy scp protocol (-O)."
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
    # modify the .pub file — selected keys go into a temp file, then get appended
    # to the target's authorized_keys (skipping any already present) over SSH.
    PUBFILE="$HOME/.ssh/id_ed25519.pub"
    GENUINE_KEY="$(ssh-keygen -y -f "$HOME/.ssh/id_ed25519" | awk '{print $1" "$2}')"
    mapfile -t KEY_LINES < <(grep -vE '^[[:space:]]*$' "$PUBFILE")

    echo -e "\n=== SELECT KEY(S) TO COPY ==="
    # Build display labels and the default selection (key matching the private key),
    # then hand off to the shared review/confirm/add/remove loop.
    KEY_OPTS=(); GENUINE_IDX=1
    for i in "${!KEY_LINES[@]}"; do
        body="$(awk '{print $1" "$2}' <<< "${KEY_LINES[$i]}")"
        comment="$(awk '{print $3}' <<< "${KEY_LINES[$i]}")"
        if [[ "$body" == "$GENUINE_KEY" ]]; then
            KEY_OPTS+=("${comment:-<no comment>}  <- your login key (matches id_ed25519)")
            GENUINE_IDX=$((i + 1))
        else
            KEY_OPTS+=("${comment:-<no comment>}")
        fi
    done
    KEY_SEL=("$GENUINE_IDX")               # default: your own login key
    review_selection KEY_OPTS KEY_SEL "key"

    # Temp file holding just the selected public keys.
    SEL_PUB="$(mktemp)"
    trap 'rm -f "$SEL_PUB"' EXIT
    : > "$SEL_PUB"
    for n in "${KEY_SEL[@]:-}"; do
        [[ -z "$n" ]] && continue
        printf '%s\n' "${KEY_LINES[$((n - 1))]}" >> "$SEL_PUB"
    done

    # Then optionally pull more keys from a gitignored extra-keys file (e.g.
    # teammates' keys you keep out of git). One public key per line; blank lines
    # and lines starting with '#' are ignored. Same confirm/add/remove selector —
    # pick some or all. Selected keys are appended to the same SEL_PUB, so the one
    # SSH copy below pushes everything (the remote side still skips duplicates).
    EXTRA_KEYS_FILE="$_SELF_DIR/extra_keys.pub"
    if [[ -f "$EXTRA_KEYS_FILE" ]]; then
        mapfile -t EXTRA_LINES < <(grep -vE '^[[:space:]]*(#|$)' "$EXTRA_KEYS_FILE")
        if (( ${#EXTRA_LINES[@]} > 0 )); then
            echo -e "\n=== EXTRA KEYS FILE ==="
            echo "Found $EXTRA_KEYS_FILE with ${#EXTRA_LINES[@]} key(s)."
            read -rp "Also copy key(s) from this file to the target? [y/N]: " _use_extra
            if [[ "$_use_extra" == [yY] ]]; then
                EXTRA_OPTS=()
                for _line in "${EXTRA_LINES[@]}"; do
                    _type="$(awk '{print $1}' <<< "$_line")"
                    _comment="$(awk '{print $3}' <<< "$_line")"
                    EXTRA_OPTS+=("${_comment:-<no comment>} (${_type:-key})")
                done
                EXTRA_SEL=()   # default: none selected — add some, or all
                review_selection EXTRA_OPTS EXTRA_SEL "extra key"
                for n in "${EXTRA_SEL[@]:-}"; do
                    [[ -z "$n" ]] && continue
                    printf '%s\n' "${EXTRA_LINES[$((n - 1))]}" >> "$SEL_PUB"
                done
            fi
        fi
    fi

    if [[ ! -s "$SEL_PUB" ]]; then
        echo "[ERR] No valid key selected — skipping key copy."
    else
        if ! grep -qF "$GENUINE_KEY" "$SEL_PUB"; then
            echo "[WARN] Your own login key was not selected — later SSH steps may prompt for a password."
        fi
        echo
        echo "Copying selected key(s) to ${TARGET_USER}@${TARGET_IP}..."
        echo "(If prompted for a password here, it's the REMOTE login password of ${TARGET_USER}@${TARGET_IP} — not your local machine.)"
        # Append each selected key to authorized_keys, skipping any already there.
        # We do this by hand instead of ssh-copy-id, whose -i handling of a
        # standalone .pub (no matching private key) varies across OpenSSH versions.
        ssh -p "$TARGET_PORT" "${TARGET_USER}@${TARGET_IP}" '
            umask 077; mkdir -p ~/.ssh
            added=0
            while IFS= read -r _k; do
                [ -z "$_k" ] && continue
                if grep -qxF "$_k" ~/.ssh/authorized_keys 2>/dev/null; then
                    continue
                fi
                printf "%s\n" "$_k" >> ~/.ssh/authorized_keys
                added=$((added + 1))
            done
            chmod 600 ~/.ssh/authorized_keys 2>/dev/null || true
            echo "  ${added} new key(s) added to authorized_keys."
        ' < "$SEL_PUB"
    fi
fi
