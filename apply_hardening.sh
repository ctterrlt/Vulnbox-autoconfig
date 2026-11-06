#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Apply only the defensive configuration files explicitly selected for this run.
set -euo pipefail

backup_file() {
    local path="$1"
    if [[ -e "$path" ]]; then
        BACKUP_PATH="${path}.vulnbox-backup.$(date +%Y%m%d%H%M%S)"
        sudo cp -a "$path" "$BACKUP_PATH"
    else
        BACKUP_PATH=""
    fi
}

restore_file() {
    local path="$1" backup="$2"
    if [[ -n "$backup" ]]; then
        sudo cp -a "$backup" "$path"
    else
        sudo rm -f "$path"
    fi
}

reload_ssh() {
    local service
    if sudo systemctl cat sshd.service >/dev/null 2>&1; then
        service=sshd
    elif sudo systemctl cat ssh.service >/dev/null 2>&1; then
        service=ssh
    else
        echo "[!] No sshd.service or ssh.service unit found." >&2
        return 1
    fi
    sudo systemctl reload-or-restart "$service"
}

if [[ -f /tmp/sshd_00-custom-ssh.conf ]]; then
    sshd_dest=/etc/ssh/sshd_config.d/00-custom-ssh.conf
    sudo mkdir -p "$(dirname "$sshd_dest")"
    backup_file "$sshd_dest"
    sshd_backup="$BACKUP_PATH"

    sshd_candidate=$(mktemp)
    if [[ "${TARGET_PORT:-22222}" != 22222 ]]; then
        printf 'Port %s\n' "$TARGET_PORT" > "$sshd_candidate"
    fi
    cat /tmp/sshd_00-custom-ssh.conf >> "$sshd_candidate"
    sudo install -m 644 "$sshd_candidate" "$sshd_dest"
    rm -f "$sshd_candidate"

    if ! sudo sshd -t; then
        restore_file "$sshd_dest" "$sshd_backup"
        echo "[!] sshd rejected the hardening config; restored the previous drop-in." >&2
        exit 1
    fi
    if ! reload_ssh; then
        restore_file "$sshd_dest" "$sshd_backup"
        reload_ssh || echo "[!] SSH service did not reload the restored config." >&2
        echo "[!] SSH reload failed; restored the previous drop-in." >&2
        exit 1
    fi
    echo "SSH hardening config validated and installed at $sshd_dest."
fi

if [[ -f /tmp/nftables.conf ]]; then
    nft_service_exec=$(sudo systemctl show --property=ExecStart --value nftables.service 2>/dev/null || true)
    case "$nft_service_exec" in
        *"/etc/sysconfig/nftables.conf"*) nft_dest=/etc/sysconfig/nftables.conf ;;
        *"/etc/nftables.conf"*) nft_dest=/etc/nftables.conf ;;
        *)
            echo "[!] Could not identify the nftables service config path; refusing to enable an unrelated file." >&2
            exit 1
            ;;
    esac
    backup_file "$nft_dest"
    nft_backup="$BACKUP_PATH"
    nft_runtime_backup=$(mktemp)
    if sudo nft list table inet vulnbox_autoconfig > "$nft_runtime_backup" 2>/dev/null; then
        had_nft_runtime_table=yes
    else
        had_nft_runtime_table=no
    fi

    nft_candidate=$(mktemp)
    nft_persist_candidate=$(mktemp)
    if [[ -n "${TARGET_PORT:-}" && "$TARGET_PORT" != 22222 ]]; then
        sed "s/tcp dport 22222 accept/tcp dport { 22222, ${TARGET_PORT} } accept/g" \
            /tmp/nftables.conf > "$nft_candidate"
    else
        cp /tmp/nftables.conf "$nft_candidate"
    fi

    if [[ -f "$nft_dest" ]]; then
        awk '
            /^# BEGIN Vulnbox-AutoConfig managed rules$/ { skip=1; next }
            /^# END Vulnbox-AutoConfig managed rules$/ { skip=0; next }
            !skip { print }
        ' "$nft_dest" > "$nft_persist_candidate"
    else
        printf '#!/usr/bin/nft -f\n' > "$nft_persist_candidate"
    fi
    {
        printf '\n# BEGIN Vulnbox-AutoConfig managed rules\n'
        sed '1{/^#!\/usr\/bin\/nft -f$/d;}' "$nft_candidate"
        printf '\n# END Vulnbox-AutoConfig managed rules\n'
    } >> "$nft_persist_candidate"

    if ! sudo nft -c -f "$nft_candidate" || ! sudo nft -c -f "$nft_persist_candidate"; then
        rm -f "$nft_candidate" "$nft_persist_candidate" "$nft_runtime_backup"
        echo "[!] nftables rejected the ruleset; no firewall changes were applied." >&2
        exit 1
    fi
    if ! sudo install -m 644 "$nft_persist_candidate" "$nft_dest"; then
        restore_file "$nft_dest" "$nft_backup"
        rm -f "$nft_candidate" "$nft_persist_candidate" "$nft_runtime_backup"
        echo "[!] Could not persist nftables rules; no firewall changes were applied." >&2
        exit 1
    fi
    if ! sudo nft -f "$nft_candidate"; then
        restore_file "$nft_dest" "$nft_backup"
        if [[ "$had_nft_runtime_table" == yes ]]; then
            sudo nft -f "$nft_runtime_backup" || true
        else
            sudo nft destroy table inet vulnbox_autoconfig || true
        fi
        rm -f "$nft_candidate" "$nft_persist_candidate" "$nft_runtime_backup"
        echo "[!] Could not load the nftables ruleset." >&2
        exit 1
    fi
    rm -f "$nft_candidate" "$nft_persist_candidate"

    if ! sudo systemctl enable --now nftables; then
        restore_file "$nft_dest" "$nft_backup"
        if [[ "$had_nft_runtime_table" == yes ]]; then
            sudo nft -f "$nft_runtime_backup" || true
        else
            sudo nft destroy table inet vulnbox_autoconfig || true
        fi
        sudo systemctl reload-or-restart nftables || true
        rm -f "$nft_runtime_backup"
        echo "[!] nftables service failed; restored its previous config and runtime table." >&2
        exit 1
    fi
    rm -f "$nft_runtime_backup"
    echo "nftables rules validated and installed. Other nftables tables are preserved."
fi

if [[ -f /tmp/fail2ban_jail.local ]]; then
    fail2ban_dest=/etc/fail2ban/jail.local
    sudo mkdir -p "$(dirname "$fail2ban_dest")"
    backup_file "$fail2ban_dest"
    fail2ban_backup="$BACKUP_PATH"
    fail2ban_candidate=$(mktemp)
    if [[ -n "${TARGET_PORT:-}" && "$TARGET_PORT" != 22222 ]]; then
        sed "s/^port = 22222$/port = 22222,${TARGET_PORT}/" \
            /tmp/fail2ban_jail.local > "$fail2ban_candidate"
    else
        cp /tmp/fail2ban_jail.local "$fail2ban_candidate"
    fi
    sudo install -m 644 "$fail2ban_candidate" "$fail2ban_dest"
    rm -f "$fail2ban_candidate"

    if ! sudo fail2ban-client -t; then
        restore_file "$fail2ban_dest" "$fail2ban_backup"
        echo "[!] Fail2ban rejected the jail config; restored the previous file." >&2
        exit 1
    fi
    if ! sudo systemctl enable --now fail2ban || ! sudo systemctl reload-or-restart fail2ban; then
        restore_file "$fail2ban_dest" "$fail2ban_backup"
        sudo systemctl reload-or-restart fail2ban || true
        echo "[!] Fail2ban failed to start with the new jail; restored the previous file." >&2
        exit 1
    fi
    echo "Fail2ban jail validated and installed at $fail2ban_dest."
fi

if [[ -f /tmp/sysctl_90-no-ping.conf ]]; then
    sysctl_dest=/etc/sysctl.d/90-no-ping.conf
    sudo mkdir -p "$(dirname "$sysctl_dest")"
    backup_file "$sysctl_dest"
    sysctl_backup="$BACKUP_PATH"
    previous_ping_value=$(sudo sysctl -n net.ipv4.icmp_echo_ignore_all)
    if ! sudo install -m 644 /tmp/sysctl_90-no-ping.conf "$sysctl_dest"; then
        restore_file "$sysctl_dest" "$sysctl_backup"
        echo "[!] Could not install the sysctl config; restored the previous file." >&2
        exit 1
    fi
    if ! sudo sysctl -p "$sysctl_dest"; then
        restore_file "$sysctl_dest" "$sysctl_backup"
        if [[ -n "$sysctl_backup" ]]; then
            sudo sysctl -p "$sysctl_backup" || true
        else
            sudo sysctl -w "net.ipv4.icmp_echo_ignore_all=$previous_ping_value" || true
        fi
        echo "[!] Could not apply the sysctl setting; the persistent file was not changed." >&2
        exit 1
    fi
    echo "sysctl hardening applied and installed at $sysctl_dest."
fi
