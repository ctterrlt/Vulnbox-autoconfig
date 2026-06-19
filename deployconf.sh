#!/usr/bin/env bash
# deployconf.sh — shared local setup + "what to deploy" prompts.
#
# Sourced by every <distro>/<distro>_auto.sh right after sshconf.sh, so the three
# deploy scripts stay in sync (the per-distro part is only the package install /
# payload). Runs in the caller's shell; it reads these from the caller:
#   DIR, TARGET_IP, TARGET_USER, TARGET_PORT
# and sets these for the payload that follows:
#   INSTALL_REQS, DEPLOY_NVIM, DEPLOY_GIT, DEPLOY_TLS,
#   DEV_REPO_URL / DEV_REPO_NAME / DEV_REPO_BRANCH,
#   DO_BACKUP, BACKUP_PATHS, BACKUP_DEST

# ── (LOCAL) PYTHON EXPLOIT DEPENDENCIES ──────────────────────────────────────
# The xfarm exploits run on THIS operator PC (never the vulnbox). Offer to install
# all their Python deps here from the aggregated root requirements.txt — kept in
# sync from every sub-requirements.txt by scripts/gen_requirements.py.
ROOT_REQ="$DIR/../requirements.txt"
read -rp "Install all Python exploit deps from requirements.txt on THIS machine? (y/N) " INSTALL_REQS
if [[ ${INSTALL_REQS:-} == [yY] ]]; then
    if [ -f "$ROOT_REQ" ]; then
        echo "  Installing $ROOT_REQ locally (pip)..."
        python3 -m pip install -r "$ROOT_REQ" \
          || python3 -m pip install --user --break-system-packages -r "$ROOT_REQ" \
          || echo "  (pip failed — install manually, or use a venv: python3 -m venv .venv)"
    else
        echo "  $ROOT_REQ not found — run ./auto.sh from the repo root to generate it."
    fi
fi

# ── DEPLOYING PAYLOAD: choose what to ship ───────────────────────────────────
echo -e "\n=== 2. DEPLOYING PAYLOAD ==="

# The box may already have a Neovim config — only deploy ours if asked.
read -rp "Deploy the Neovim config to ~/.config/nvim/init.lua on the target? (y/N) " DEPLOY_NVIM

# Optionally push the shared git aliases to the target's ~/.gitconfig.
read -rp "Deploy the git aliases (gitconfig.conf) to the target's ~/.gitconfig? (y/N) " DEPLOY_GIT

# The TLS bridge runs ON the vulnbox (unlike the xfarm exploits) — offer to ship it.
read -rp "Deploy the TLS interception bridge (python_exploits/tls) to ~/tls_bridge on the target? (y/N) " DEPLOY_TLS

# After everything else, optionally clone this toolkit's own dev branch onto the box.
read -rp "Also clone this toolkit's dev branch into ~/<repo> on the target once setup finishes? (y/N) " DEPLOY_DEV
DEV_REPO_URL=""
DEV_REPO_NAME=""
DEV_REPO_BRANCH="dev"
if [[ $DEPLOY_DEV == [yY] ]]; then
    # Derive the clone URL from this checkout's origin; rewrite an SSH remote to its
    # HTTPS form so the vulnbox needs no GitHub key of its own.
    DEV_REPO_URL=$(git -C "$DIR" remote get-url origin 2>/dev/null || true)
    if [[ $DEV_REPO_URL == git@*:* ]]; then
        _hp=${DEV_REPO_URL#git@}; DEV_REPO_URL="https://${_hp%%:*}/${_hp#*:}"
    elif [[ $DEV_REPO_URL == ssh://git@* ]]; then
        DEV_REPO_URL="https://${DEV_REPO_URL#ssh://git@}"
    fi
    if [[ -z $DEV_REPO_URL ]]; then
        echo "  Couldn't determine this repo's origin URL — skipping the dev clone."
    else
        DEV_REPO_NAME=$(basename "$DEV_REPO_URL" .git)
        echo "  Will clone $DEV_REPO_URL (branch $DEV_REPO_BRANCH) into ~/$DEV_REPO_NAME on the target after setup."
    fi
fi

# Backups can be huge — opt in, and pick exactly what to archive (not always home).
read -rp "Pull a backup from the target before finishing? (y/N) " DO_BACKUP
BACKUP_PATHS=""
BACKUP_DEST="$HOME"
if [[ $DO_BACKUP == [yY] ]]; then
    DO_BACKUP=y
    # Show what's in the target's home so you can choose folders by name (lsd if present).
    echo "--- contents of the target's home directory ---"
    ssh -p "$TARGET_PORT" "${TARGET_USER}@${TARGET_IP}" \
        'cd ~ && { command -v lsd >/dev/null 2>&1 && lsd -lah || ls -lah; }' || true
    echo "-----------------------------------------------"
    echo "Paths may be: a name under home (Immagini), a ~ path (~/Immagini), or an"
    echo "absolute path (/var/www, /etc/nginx); a trailing slash is fine."
    while true; do
        read -rp "Folder(s) to zip — e.g. Immagini, ~/Immagini, or /abs/path (space-separated), blank = whole home: " BACKUP_PATHS
        if [[ -z "$BACKUP_PATHS" ]]; then
            read -rp "No folders selected — zip the WHOLE home dir? ([y]es / [r]e-enter / [n]o backup) " ans
            case "$ans" in
                [yY]) echo "  -> backing up the whole home directory."; break ;;
                [rR]) continue ;;
                *)    DO_BACKUP=n; echo "  -> backup cancelled."; break ;;
            esac
        else
            # Normalize bare names to ~/name and show where each resolves on the target.
            _norm=""
            for _p in $BACKUP_PATHS; do
                case "$_p" in
                    /*|"~"|"~/"*) _q="$_p" ;;
                    *)            _q="~/$_p" ;;
                esac
                _norm+="${_norm:+ }$_q"
            done
            BACKUP_PATHS="$_norm"
            echo "Selected for backup (on the target):"
            for _p in $BACKUP_PATHS; do
                case "$_p" in */) echo "    - $_p" ;; *) echo "    - $_p/" ;; esac
            done
            read -rp "Proceed with these? [Y]es (Enter) / [r]e-enter: " ans
            if [[ "$ans" == [rR] ]]; then continue; fi
            break
        fi
    done
    if [[ $DO_BACKUP == y ]]; then
        echo
        read -rp "Where should the pulled backup be saved locally? [${HOME}]: " BACKUP_DEST
        BACKUP_DEST="${BACKUP_DEST:-$HOME}"
        case "$BACKUP_DEST" in
            "~")   BACKUP_DEST="$HOME" ;;
            "~/"*) BACKUP_DEST="$HOME/${BACKUP_DEST#\~/}" ;;
        esac
        mkdir -p "$BACKUP_DEST"
    fi
else
    DO_BACKUP=n
fi
