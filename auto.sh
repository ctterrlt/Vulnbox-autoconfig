#!/bin/bash
# auto_deploy.sh
set -euo pipefail

# ── Safety guard: must be run from the repo root ──────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "$PWD" != "$SCRIPT_DIR" ]]; then
    echo "[!] Run this script from the repo root: cd $SCRIPT_DIR"
    exit 1
fi

# ── Safety guard: refuse to run inside a Docker container ─────────────────────
if [[ -f /.dockerenv ]] || grep -qE '(docker|containerd|lxc)' /proc/1/cgroup 2>/dev/null; then
    echo "[DANGER] Docker/container environment detected. Aborting."
    echo "         This tool is meant to be run from your LOCAL machine only."
    exit 1
fi

# ── Ensure all scripts are executable ─────────────────────────────────────────
find "$SCRIPT_DIR" -name "*.sh" -exec chmod +x {} \;

echo "========================================"
echo "   VULNBOX MASTER DEPLOYMENT CENTER     "
echo "========================================"

PS3="Select target distribution: "
options=("Arch" "Debian/Ubuntu" "Fedora" "Quit")

select opt in "${options[@]}"; do
    case $opt in
        "Arch")
            "$SCRIPT_DIR/arch/arch_auto.sh"
            break
            ;;
        "Debian/Ubuntu")
            "$SCRIPT_DIR/debian_ubuntu/debian_ubuntu_auto.sh"
            break
            ;;
        "Fedora")
            "$SCRIPT_DIR/fedora/fedora_auto.sh"
            break
            ;;
        "Quit")
            exit 0
            ;;
        *)
            echo "Invalid option '$REPLY'. Please enter a number from the list."
            ;;
    esac
done
