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

# ── Keep the aggregated root requirements.txt fresh + wire its auto-update hook ─
# scripts/gen_requirements.py rebuilds requirements.txt as the union of every
# sub-requirements.txt; the .githooks/pre-commit hook reruns it on each commit.
if git -C "$SCRIPT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "$SCRIPT_DIR" config core.hooksPath .githooks 2>/dev/null || true
fi
python3 "$SCRIPT_DIR/scripts/gen_requirements.py" 2>/dev/null || true

# Seed the gitignored extra_keys.pub from its tracked template on first run, so the
# file always exists locally after a clone (your keys stay out of git — only the
# .example template is committed).
if [ ! -f "$SCRIPT_DIR/extra_keys.pub" ] && [ -f "$SCRIPT_DIR/extra_keys.pub.example" ]; then
    cp "$SCRIPT_DIR/extra_keys.pub.example" "$SCRIPT_DIR/extra_keys.pub"
    echo "[OK] Created extra_keys.pub from the template — add extra public keys there (gitignored)."
fi

# Shared selection helper (review_selection: list selected → confirm/add/remove).
. "$SCRIPT_DIR/selectlib.sh"

# ── Global Git Configuration Setup ────────────────────────────────────────────

echo ""
echo "========================================"
echo "       GIT CONFIGURATION SETUP          "
echo "========================================"

GIT_CONF_SRC="$SCRIPT_DIR/gitconfig.conf"
if [[ -f "$GIT_CONF_SRC" ]]; then
    CURRENT_INCLUDES=$(git config --global --get-all include.path 2>/dev/null || true)

    read -r -p "Import/refresh Vulnbox Git config into your ~/.gitconfig? (y/N) " link_aliases
    if [[ "$link_aliases" == [yY]* ]]; then
        read -r -p "Import [a]ll, or choose [i]tem per item? (a/i) [a]: " git_mode
        git_mode=${git_mode:-a}
        if [[ "$git_mode" == [iI]* ]]; then
            # Per-item: read each entry's value from the source via git itself
            # (no manual ini parsing — keeps complex values like 'lg' intact),
            # then apply only the chosen ones to ~/.gitconfig.
            mapfile -t GIT_KEYS < <(git config -f "$GIT_CONF_SRC" --list --name-only)
            GIT_OPTS=()
            for key in "${GIT_KEYS[@]}"; do
                GIT_OPTS+=("${key} = $(git config -f "$GIT_CONF_SRC" --get "$key")")
            done
            GIT_SEL=()   # start empty — add the entries you want
            review_selection GIT_OPTS GIT_SEL "entry"
            imported=0
            for n in "${GIT_SEL[@]:-}"; do
                [[ -z "$n" ]] && continue
                key="${GIT_KEYS[$((n - 1))]}"
                git config --global "$key" "$(git config -f "$GIT_CONF_SRC" --get "$key")"
                echo "    [+] ${key}"
                imported=$((imported + 1))
            done
            echo "[SUCCESS] Imported ${imported} Git entr$([[ $imported -eq 1 ]] && echo y || echo ies) into ~/.gitconfig."
        else
            # Remove any existing include.path for this file first, so re-running
            # auto.sh always refreshes the link (picks up changes to gitconfig.conf).
            if [[ "$CURRENT_INCLUDES" == *"$GIT_CONF_SRC"* ]]; then
                git config --global --unset-all include.path "$GIT_CONF_SRC" 2>/dev/null || true
            fi
            git config --global --add include.path "$GIT_CONF_SRC"
            echo "[SUCCESS] Linked/refreshed all Vulnbox Git config to your ~/.gitconfig."
        fi
    else
        echo "[SKIPPED] Git config not imported."
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

# ── Git clone protocol preference ─────────────────────────────────────────────
# Ask once: applies to both local Pwnzer0tt1 clones and the dev-repo clone on
# the target (via deployconf.sh, which sources this env var).
GIT_CLONE_PROTOCOL="${GIT_CLONE_PROTOCOL:-https}"
echo ""
read -rp "Protocol for cloning onto the vulnbox (and for Pwnzer0tt1 clones)? ([S]SH / [H]TTPS) [H]: " _clone_proto
case "${_clone_proto:-}" in
    [sS]*) GIT_CLONE_PROTOCOL="ssh"; echo "  -> using SSH for git clones" ;;
    *)    GIT_CLONE_PROTOCOL="https"; echo "  -> using HTTPS for git clones" ;;
esac
export GIT_CLONE_PROTOCOL

# ── Main Deployment Menu ──────────────────────────────────────────────────────
echo "========================================"
echo "    VULNBOX MASTER DEPLOYMENT CENTER    "
echo "========================================"

PS3="Select an option: "
options=("Arch" "Debian/Ubuntu" "Fedora" "Install/update ExploitFarm tooling (exploitfarm/digger/firegex)" "Quit")

_menu_first=1
select opt in "${options[@]}"; do
    # Reprint menu after returning from a sub-menu (select only prints it on the first pass)
    if (( ! _menu_first )); then
        echo ""
        for _i in "${!options[@]}"; do
            printf "%d) %s\n" "$((_i + 1))" "${options[$_i]}"
        done
    fi
    _menu_first=0
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
        "Install/update ExploitFarm tooling (exploitfarm/digger/firegex)")
            # Robust installer — never aborts auto.sh even if it errors.
            # Run in a subshell with errexit disabled so isolated failures are safe.
            (
                set +euo pipefail 2>/dev/null || true
                PWNZER_DIR="${PWNZER_DIR:-$HOME/pwnzerotti}"

                github_url() {
                    local repo="$1"
                    if [[ "${GIT_CLONE_PROTOCOL:-https}" == "ssh" ]]; then
                        echo "git@github.com:${repo}"
                    else
                        echo "https://github.com/${repo}"
                    fi
                }
                URL_exploitfarm=$(github_url "Pwnzer0tt1/exploitfarm")
                URL_digger=$(github_url "Pwnzer0tt1/digger")
                URL_firegex=$(github_url "Pwnzer0tt1/firegex")

                has_remote_branch() {
                    local url="$1" branch="$2"
                    git ls-remote --heads "$url" "$branch" 2>/dev/null | grep -q "refs/heads/$branch"
                }

                resolve_branch() {
                    local name="$1" url="$2" mode="$3"
                    case "$mode" in
                        dev)
                            if has_remote_branch "$url" dev; then
                                echo "dev"; return
                            fi
                            echo "  ($name has no dev branch on remote — using main)" >&2
                            echo "main"
                            ;;
                        ask)
                            if has_remote_branch "$url" dev; then
                                echo "    1) main    2) dev"
                                read -rp "  Branch for $name? Enter number or name [main]: " _b
                                case "${_b:-1}" in 1|[mM]*) echo "main"; return ;; 2|[dD]*) echo "dev"; return ;; esac
                            fi
                            echo "main"
                            ;;
                        *) echo "main" ;;
                    esac
                }

                ensure_repo() {
                    local name="$1" url="$2" branch="$3"
                    local dest="$PWNZER_DIR/$name"
                    mkdir -p "$PWNZER_DIR" 2>/dev/null || true

                    if ! command -v git >/dev/null 2>&1; then
                        echo "    [!] git not found — cannot install $name. Skipping."
                        return 0
                    fi

                    if [ -d "$dest/.git" ]; then
                        local current_branch
                        current_branch="$(git -C "$dest" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
                        echo "[*] $name at $dest (current: $current_branch) — updating to $branch..."

                        git -C "$dest" remote set-url origin "$url" 2>/dev/null || true
                        git -C "$dest" fetch origin "$branch" 2>/dev/null \
                            || git -C "$dest" fetch --all 2>/dev/null \
                            || true

                        if [ "$current_branch" != "$branch" ]; then
                            echo "    Branch switch: $current_branch → $branch"
                            echo "      1) stash  — stash local changes, switch, pop stash"
                            echo "      2) reset  — discard local changes & hard-switch"
                            echo "      3) abort  — skip $name"
                            echo "      Enter number or name"
                            read -rp "    How to proceed? [stash]: " _conflict
                            case "${_conflict:-1}" in
                                2|[rR]*)
                                    git -C "$dest" checkout -B "$branch" "origin/$branch" 2>/dev/null || \
                                    git -C "$dest" checkout "$branch" 2>/dev/null || true
                                    git -C "$dest" reset --hard "origin/$branch" 2>/dev/null || true
                                    git -C "$dest" clean -fd 2>/dev/null || true
                                    echo "    -> hard reset to origin/$branch"
                                    ;;
                                3|[aA]*)
                                    echo "    -> skipped $name"
                                    return 0
                                    ;;
                                *)
                                    git -C "$dest" stash 2>/dev/null || true
                                    git -C "$dest" checkout -B "$branch" "origin/$branch" 2>/dev/null || \
                                    git -C "$dest" checkout "$branch" 2>/dev/null || true
                                    git -C "$dest" stash pop 2>/dev/null \
                                        || echo "    [warn] stash pop had conflicts — check $dest manually"
                                    echo "    -> stashed, switched, popped"
                                    ;;
                            esac
                        else
                            if ! git -C "$dest" pull --rebase origin "$branch" 2>/dev/null; then
                                echo "    [!] pull/rebase hit a snag — hard-syncing to origin/$branch (local changes discarded)."
                                git -C "$dest" rebase --abort 2>/dev/null || true
                                git -C "$dest" reset --hard "origin/$branch" 2>/dev/null || true
                                git -C "$dest" clean -fd 2>/dev/null || true
                            fi
                        fi
                    else
                        echo "[*] Cloning $name ($branch) into $dest..."
                        rm -rf "$dest" 2>/dev/null || true
                        git clone -b "$branch" "$url" "$dest" 2>/dev/null \
                            || { echo "    [!] clone failed (network/git?) — skipping $name."; return 0; }
                    fi

                    local br
                    br="$(git -C "$dest" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
                    echo "[+] $name ready at $dest (branch: $br)."
                    return 0
                }

                build_repo() {
                    local name="$1" dest="$PWNZER_DIR/$name"
                    [ -d "$dest" ] || return 0
                    echo "[*] Best-effort build for $name (failures are non-fatal)..."
                    if [ -f "$dest/docker-compose.yml" ] || [ -f "$dest/compose.yml" ] || [ -f "$dest/docker-compose.yaml" ]; then
                        ( cd "$dest" && { docker compose build || docker-compose build; } ) 2>&1 | sed 's/^/    /' || true
                    elif [ -f "$dest/Makefile" ]; then
                        ( cd "$dest" && make ) 2>&1 | sed 's/^/    /' || true
                    elif [ -f "$dest/requirements.txt" ]; then
                        python3 -m pip install -r "$dest/requirements.txt" 2>/dev/null \
                          || python3 -m pip install --user --break-system-packages -r "$dest/requirements.txt" 2>/dev/null || true
                    else
                        echo "    (no known build file detected — see $dest/README for build/run steps.)"
                    fi
                    return 0
                }

                install_tool() {
                    local name="$1" url="$2" mode="$3"
                    local branch
                    branch="$(resolve_branch "$name" "$url" "$mode")"
                    ensure_repo "$name" "$url" "$branch"
                    read -rp "    Build $name now? (heavy — recompiles from source) [y/N]: " _b || true
                    [[ "${_b:-}" == [yY]* ]] && build_repo "$name"
                    [ "$name" = "exploitfarm" ] && echo "    Start ExploitFarm with:  cd '$PWNZER_DIR/exploitfarm' && python3 run.py start --prebuilt"
                    return 0
                }

                echo "==================================================================="
                echo "  Pwnzer0tt1 ExploitFarm stack — install / update"
                echo "==================================================================="
                echo "Repos live under: $PWNZER_DIR    (override with  PWNZER_DIR=...)"
                echo "Note: cloning or pulling recompiles from source — digger is large and slow."
                echo

                BRANCH_MODE="main"
                echo "  Branch preference for Pwnzer0tt1 repos:"
                echo "    1) main  — stable, recommended"
                echo "    2) dev   — latest, may be unstable"
                echo "    3) ask   — decide per repo (prompts if dev exists)"
                echo "    Enter number or name"
                read -rp "    Which? [main]: " _branch_choice
                case "${_branch_choice:-1}" in
                    2|[dD]*) BRANCH_MODE="dev"; echo "  -> using dev branch where available" ;;
                    3|[aA]*) BRANCH_MODE="ask"; echo "  -> will ask per repo" ;;
                    *)       BRANCH_MODE="main"; echo "  -> using main branch" ;;
                esac
                echo

                while true; do
                    echo
                    echo "  1) exploitfarm    2) digger    3) firegex    4) all    5) back"
                    echo "  Enter number or name"
                    read -rp "Install/update which? [5]: " _c || true
                    case "${_c:-5}" in
                        1|[eE]*) install_tool exploitfarm "$URL_exploitfarm" "$BRANCH_MODE" ;;
                        2|[dD]*) install_tool digger      "$URL_digger"      "$BRANCH_MODE" ;;
                        3|[fF]*) install_tool firegex     "$URL_firegex"     "$BRANCH_MODE" ;;
                        4|[aA]*) install_tool exploitfarm "$URL_exploitfarm" "$BRANCH_MODE"
                                install_tool digger      "$URL_digger"      "$BRANCH_MODE"
                                install_tool firegex     "$URL_firegex"     "$BRANCH_MODE" ;;
                        5|[bBqQ]*) break ;;
                        *) echo "  invalid choice — pick 1-5 or enter the name." ;;
                    esac
                done
            ) || true
            continue
            ;;
        "Quit")
            exit 0
            ;;
        *)
            echo "Invalid option '$REPLY'. Please enter a number from the list."
            ;;
    esac
done

# ── Post-deploy: prompt to stay in vuln or return to local PC ─────────────────
if [[ -f /tmp/.vulnbox_target ]]; then
    IFS=: read -r TARGET_USER TARGET_IP TARGET_PORT < /tmp/.vulnbox_target
    rm -f /tmp/.vulnbox_target

    echo ""
    echo "========================================"
    echo "    DEPLOYMENT COMPLETE                  "
    echo "========================================"
    read -r -p "Stay logged into vulnbox? (Y/n) " stay_logged
    stay_logged=${stay_logged:-Y}
    if [[ "$stay_logged" == [yY]* ]]; then
        echo -e "\n=== LOGGING IN ==="
        echo "(reloading zsh config via 'zsh' alias = source ~/.zshrc)"
        ssh -p "$TARGET_PORT" -t "${TARGET_USER}@${TARGET_IP}" "cd ~ && exec zsh -c 'source ~/.zshrc && exec zsh -i'"
    else
        echo "Returned to local shell."
    fi
fi
