#!/usr/bin/env bash
# deployconf.sh — shared local setup + "what to deploy" prompts.
#
# Sourced by every <distro>/<distro>_auto.sh right after sshconf.sh, so the three
# deploy scripts stay in sync (the per-distro part is only the package install /
# payload). Runs in the caller's shell; it reads these from the caller:
#   DIR, TARGET_IP, TARGET_USER, TARGET_PORT
# and sets these for the payload that follows:
#   INSTALL_REQS, DEPLOY_NVIM, DEPLOY_GIT, DEPLOY_TLS, DEPLOY_NANO, DEPLOY_KONSOLE,
#   DEPLOY_ROOTSHELL, DEV_REPO_URL / DEV_REPO_NAME / DEV_REPO_BRANCH,
#   DO_BACKUP, BACKUP_PATHS, BACKUP_DEST

# ── (LOCAL) PYTHON EXPLOIT DEPENDENCIES ──────────────────────────────────────
# The xfarm exploits run on THIS operator PC (never the vulnbox). Offer to install
# all their Python deps here from the aggregated root requirements.txt — kept in
# sync from every sub-requirements.txt by scripts/gen_requirements.py.
ROOT_REQ="$DIR/../requirements.txt"
read -rp "Install all Python exploit deps from requirements.txt on THIS machine? (y/N) " INSTALL_REQS
if [[ ${INSTALL_REQS:-} == [yY]* ]]; then
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

# Drop a nano config (~/.nanorc) — line numbers, syntax highlight, sane defaults.
read -rp "Deploy the nano config (nanorc) to the target's ~/.nanorc? (y/N) " DEPLOY_NANO

# Drop a Konsole config (~/.config/konsolerc + profile). Konsole is KDE's GUI
# terminal — usually irrelevant on a headless vulnbox, hence default no — but the
# files are harmless if konsole isn't installed and ready if it is.
read -rp "Deploy the Konsole config (konsolerc + profile) to the target? (y/N) " DEPLOY_KONSOLE

# Also give the TARGET's root the same zsh setup, so `sudo su` / `su -` on the box
# keep your config instead of a bare bash. Defaults to yes. Skipped automatically
# when you deploy AS root (root is already configured as the login user then).
read -rp "Also set the TARGET's root shell to this zsh config (so 'sudo su' on the box keeps it)? (Y/n) " DEPLOY_ROOTSHELL

# After everything else, optionally clone this toolkit onto the box.
read -rp "Also clone this toolkit into ~/<repo> on the target once setup finishes? (y/N) " DEPLOY_DEV
DEV_REPO_URL=""
DEV_REPO_NAME=""
DEV_REPO_BRANCH=""
if [[ $DEPLOY_DEV == [yY]* ]]; then
    echo "    1) main    2) dev"
    read -rp "  Which branch to clone? Enter number or name [main]: " _branch_in
    case "${_branch_in:-1}" in 2|[dD]*) DEV_REPO_BRANCH="dev" ;; *) DEV_REPO_BRANCH="main" ;; esac
    # Derive the clone URL from this checkout's origin; convert protocol
    # according to GIT_CLONE_PROTOCOL (https → SSH via git@, or SSH → HTTPS).
    DEV_REPO_URL=$(git -C "$DIR" remote get-url origin 2>/dev/null || true)
    if [[ -n $DEV_REPO_URL ]]; then
        if [[ "${GIT_CLONE_PROTOCOL:-https}" == "https" ]]; then
            # SSH → HTTPS
            if [[ $DEV_REPO_URL == git@*:* ]]; then
                _hp=${DEV_REPO_URL#git@}; DEV_REPO_URL="https://${_hp%%:*}/${_hp#*:}"
            elif [[ $DEV_REPO_URL == ssh://git@* ]]; then
                DEV_REPO_URL="https://${DEV_REPO_URL#ssh://git@}"
            fi
        else
            # HTTPS → SSH (GitHub format)
            if [[ $DEV_REPO_URL == https://github.com/* ]]; then
                DEV_REPO_URL="git@github.com:${DEV_REPO_URL#https://github.com/}"
                DEV_REPO_URL="${DEV_REPO_URL%.git}.git"
            fi
        fi
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
if [[ $DO_BACKUP == [yY]* ]]; then
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
                [yY]*) echo "  -> backing up the whole home directory."; break ;;
                [rR]*) continue ;;
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
            if [[ "$ans" == [rR]* ]]; then continue; fi
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

# ── POST-BACKUP PROMPTS: remote git init / local extract / local git init ────
# All settled here while the user is in the interactive flow; consumed in the
# payload (remote git init) and after the backup download below (local extraction
# + local git init). Keeping them together avoids scattering prompts downstream.
DO_GIT_INIT_REMOTE=""
DO_EXTRACT=""
EXTRACT_DEST=""
DO_GIT_INIT_LOCAL=""
if [[ $DO_BACKUP == y ]]; then
    echo
    read -rp "Git init the selected folders on the TARGET before zipping? (y/N) " DO_GIT_INIT_REMOTE
    echo
    read -rp "Extract the pulled backup zip on THIS machine after download? (y/N) " DO_EXTRACT
    if [[ $DO_EXTRACT == [yY]* ]]; then
        read -rp "  Extract to path (blank = same folder as zip; relative = under $BACKUP_DEST): " EXTRACT_DEST
    fi
    echo
    read -rp "Git init each extracted folder locally (add .gitignore if missing)? (y/N) " DO_GIT_INIT_LOCAL
fi

# ── POST-BACKUP PROCESSING (shared across all distros) ─────────────────────────
# Called by each <distro>/<distro>_auto.sh after the backup has been pulled and
# BACKUP_FILE is known.  Handles extraction, local git init (with .gitignore),
# and prints the DEPLOYMENT WRAP-UP instructions.  Lives here so we don't
# maintain three copies of the same block.
post_backup_processing() {
    local BACKUP_FILE="$1"

    # ── EXTRACT BACKUP LOCALLY ────────────────────────────────────────────────
    local EXTRACTED_DIR=""
    if [[ $DO_BACKUP == y && $DO_EXTRACT == [yY]* ]]; then
        echo -e "\n=== EXTRACTING BACKUP ==="
        if [[ -z "$EXTRACT_DEST" ]]; then
            local _base="${BACKUP_FILE%.zip}"
            EXTRACTED_DIR="$_base"
        elif [[ "$EXTRACT_DEST" = /* ]]; then
            EXTRACTED_DIR="$EXTRACT_DEST"
        else
            EXTRACTED_DIR="${BACKUP_DEST}/${EXTRACT_DEST}"
        fi
        local _orig="$EXTRACTED_DIR"
        local _i=1
        while [[ -d "$EXTRACTED_DIR" ]]; do
            EXTRACTED_DIR="${_orig}_${_i}"
            _i=$((_i + 1))
        done
        mkdir -p "$EXTRACTED_DIR"
        echo "Extracting to $EXTRACTED_DIR ..."
        unzip -q "$BACKUP_FILE" -d "$EXTRACTED_DIR" || {
            echo "[!] Extraction failed — removing empty target dir."
            rm -rf "$EXTRACTED_DIR"
            EXTRACTED_DIR=""
        }
        if [[ -n "$EXTRACTED_DIR" ]]; then
            echo "  -> extracted to $EXTRACTED_DIR"
        fi
    fi

    # ── GIT INIT ON EXTRACTED FOLDERS ─────────────────────────────────────────
    if [[ -n "$EXTRACTED_DIR" && $DO_GIT_INIT_LOCAL == [yY]* ]]; then
        echo -e "\n=== GIT INIT ON EXTRACTED FOLDERS ==="
        local _found=0
        for _item in "$EXTRACTED_DIR"/*/; do
            [ -d "$_item" ] || continue
            _item="${_item%/}"
            local _name="$(basename "$_item")"
            if [ -d "$_item/.git" ]; then
                echo "  -> $_name already has .git (skipping init)"
            else
                git -C "$_item" init -q && echo "  -> git init'd $_name"
            fi
            if [ ! -f "$_item/.gitignore" ]; then
                cat > "$_item/.gitignore" <<- GITIGNORE_LOCAL
*.pyc
__pycache__/
.venv/
.env
*.zip
*.tar.gz
*.log
.DS_Store
GITIGNORE_LOCAL
                echo "  -> added .gitignore to $_name"
            fi
            _found=$((_found + 1))
        done
        if (( _found == 0 )); then
            if [ -d "$EXTRACTED_DIR" ]; then
                if [ ! -d "$EXTRACTED_DIR/.git" ]; then
                    git -C "$EXTRACTED_DIR" init -q && echo "  -> git init'd $(basename "$EXTRACTED_DIR")"
                fi
                if [ ! -f "$EXTRACTED_DIR/.gitignore" ]; then
                    cat > "$EXTRACTED_DIR/.gitignore" <<- GITIGNORE_LOCAL
*.pyc
__pycache__/
.venv/
.env
*.zip
*.tar.gz
*.log
.DS_Store
GITIGNORE_LOCAL
                    echo "  -> added .gitignore to $(basename "$EXTRACTED_DIR")"
                fi
            fi
        fi
    fi

    # ── DEPLOYMENT WRAP-UP: reminders ─────────────────────────────────────────
    echo -e "\n=== DEPLOYMENT WRAP-UP ==="
    echo "  What to do next on the vulnbox:"
    echo "  1. Start the tools / services you need (listeners, bridges, ...)"
    echo "  2. Add the vulnbox GitHub API key so it can push/pull:"
    echo "       git remote set-url origin https://<user>:<token>@github.com/..."
    echo "  3. Link git repos between your PC and the vulnbox"
    echo "     (set a shared remote on GitHub, or scp .git/config across)"
    echo "  4. Update .gitignore in every repo as needed"
    echo "  5. Push everything to GitHub"
    echo "  6. Restart every service that got updated config"
    echo "  7. Fine-tune exploit tool configs (paths, tokens, flag IDs)"
}

# ── DEPLOYMENT SUMMARY ─────────────────────────────────────────────────────────
# Prints a recap of everything done, with key details the operator needs.
# Called from each <distro>/<distro>_auto.sh after post_backup_processing.
print_summary() {
    echo ""
    echo "========================================="
    echo "       DEPLOYMENT SUMMARY                "
    echo "========================================="
    echo "  Target:       ${TARGET_USER}@${TARGET_IP}:${TARGET_PORT}"
    echo "  Host alias:   ${HOST_ALIAS:-<none>}"
    echo ""
    echo "  SSH key:      ~/.ssh/id_ed25519.pub"
    if [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
        echo "  Key comment:  $(awk '{print $3}' "$HOME/.ssh/id_ed25519.pub")"
        echo "  Fingerprint:  $(ssh-keygen -lf "$HOME/.ssh/id_ed25519.pub" 2>/dev/null | awk '{print $2}')"
    fi
    echo "  SCP protocol: $([ "${SCP_OPTS:--O}" = "-O" ] && echo "legacy (-O)" || echo "modern (SFTP)")"
    echo "  Git protocol: ${GIT_CLONE_PROTOCOL:-https}"
    echo ""
    echo "  Deployed features:"
    echo "    zsh config:   yes"
    echo "    root config:  $([ "${DEPLOY_ROOTSHELL:-n}" == [yY]* ] && echo "yes" || echo "no")"
    echo "    neovim:       $([ "${DEPLOY_NVIM:-n}" == [yY]* ] && echo "yes" || echo "no")"
    echo "    git aliases:  $([ "${DEPLOY_GIT:-n}" == [yY]* ] && echo "yes" || echo "no")"
    echo "    nano:         $([ "${DEPLOY_NANO:-n}" == [yY]* ] && echo "yes" || echo "no")"
    echo "    konsole:      $([ "${DEPLOY_KONSOLE:-n}" == [yY]* ] && echo "yes" || echo "no")"
    echo "    tls bridge:   $([ "${DEPLOY_TLS:-n}" == [yY]* ] && echo "yes" || echo "no")"
    echo ""
    if [ -n "${DEV_REPO_URL:-}" ]; then
        echo "  Dev repo clone:"
        echo "    URL:    $DEV_REPO_URL"
        echo "    branch: ${DEV_REPO_BRANCH:-main}"
        echo "    dest:   ~/$DEV_REPO_NAME"
    fi
    if [[ "${DO_BACKUP:-n}" == [yY]* ]]; then
        echo "  Backup:       ${BACKUP_FILE:-<pulled>}"
    fi
    echo ""
    echo "  Next steps checklist:"
    echo "  [ ] Verify passwordless login: ssh ${TARGET_USER}@${HOST_ALIAS:-$TARGET_IP}"
    echo "  [ ] Set up GitHub API key on vulnbox if using HTTPS clone"
    echo "  [ ] Start services / listeners on vulnbox"
    echo "  [ ] Configure exploit parameters (paths, tokens, flag IDs)"
    echo "  [ ] Push/backup changes to GitHub"
    echo ""
}
