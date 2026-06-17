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

# ── Global Git Configuration Setup ────────────────────────────────────────────

echo ""
echo "========================================"
echo "       GIT CONFIGURATION SETUP          "
echo "========================================"

GIT_CONF_SRC="$SCRIPT_DIR/gitconfig.conf"
if [[ -f "$GIT_CONF_SRC" ]]; then
    # '|| true' prevents set -e from exiting if no include.path is configured yet
    CURRENT_INCLUDES=$(git config --global --get-all include.path 2>/dev/null || true)

    if [[ "$CURRENT_INCLUDES" == *"$GIT_CONF_SRC"* ]]; then
        echo "[OK] Git aliases are already linked."
    else
        read -r -p "Import Vulnbox Git config into your ~/.gitconfig? (y/N) " link_aliases
        if [[ "$link_aliases" == [yY] ]]; then
            read -r -p "Import [a]ll, or choose [i]tem per item? (a/i) [a]: " git_mode
            git_mode=${git_mode:-a}
            if [[ "$git_mode" == [iI] ]]; then
                # Per-item: read each entry's value from the source via git itself
                # (no manual ini parsing — keeps complex values like 'lg' intact),
                # then apply only the chosen ones to ~/.gitconfig.
                echo "Choose which entries to import:"
                mapfile -t GIT_KEYS < <(git config -f "$GIT_CONF_SRC" --list --name-only)
                imported=0
                for key in "${GIT_KEYS[@]}"; do
                    val=$(git config -f "$GIT_CONF_SRC" --get "$key")
                    read -r -p "  import  ${key} = ${val}  ? (y/N) " pick
                    if [[ "$pick" == [yY] ]]; then
                        git config --global "$key" "$val"
                        echo "    [+] ${key}"
                        imported=$((imported + 1))
                    fi
                done
                echo "[SUCCESS] Imported ${imported} Git entr$([[ $imported -eq 1 ]] && echo y || echo ies) into ~/.gitconfig."
            else
                git config --global --add include.path "$GIT_CONF_SRC"
                echo "[SUCCESS] Linked all Vulnbox Git config to your ~/.gitconfig."
            fi
        else
            echo "[SKIPPED] Git config not imported."
        fi
    fi

    # Prompt for user.name only if unset — optional, user can skip
    if ! git config --global user.name >/dev/null 2>&1; then
        echo ""
        read -r -p "Git user.name is not set. Enter your name (or press Enter to skip): " git_name
        [[ -n "$git_name" ]] && git config --global user.name "$git_name"
    fi

    # Prompt for user.email only if unset — optional, user can skip
    if ! git config --global user.email >/dev/null 2>&1; then
        read -r -p "Git user.email is not set. Enter your email (or press Enter to skip): " git_email
        [[ -n "$git_email" ]] && git config --global user.email "$git_email"
    fi
    echo ""
else
    echo "[WARNING] gitconfig.conf not found in $SCRIPT_DIR."
    echo "          Skipping Git alias setup."
    echo ""
fi

# ── Main Deployment Menu ──────────────────────────────────────────────────────
echo "========================================"
echo "    VULNBOX MASTER DEPLOYMENT CENTER    "
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
