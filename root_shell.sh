#!/bin/bash
# root_shell.sh — make root use the SAME zsh setup as you, so `sudo su` (and any
# root shell) keeps your prompt, aliases, plugins, PATH and config instead of
# dropping to a bare bash. `sudo su` always starts ROOT's account shell, not yours,
# so the only real fix is to give root the same shell + config — which is what this
# does. Run it on the machine you want to fix:
#
#     ./root_shell.sh            # as your normal user — re-runs itself with sudo
#     sudo ./root_shell.sh       # same thing
#     ./root_shell.sh USER       # when you're ALREADY root (e.g. via `su -`), pass the
#                                # user whose config to mirror, e.g.  ./root_shell.sh Chry
#
# Idempotent and reversible:
#   * adds zsh to /etc/shells if missing
#   * sets root's login shell to zsh        (undo: sudo chsh -s /bin/bash root)
#   * installs Oh-My-Zsh into /root/.oh-my-zsh if missing
#   * symlinks your dotfiles into /root so root shares them and they stay in sync:
#       ~/.zshrc ~/.nanorc ~/.gitconfig(_vulnbox) ~/.vimrc ~/.config/nvim
#       (undo: sudo rm the matching /root/<file>)
#   * COPIES ~/.ssh/config + your identity key(s) + known_hosts into /root/.ssh
#     (ssh refuses a config it doesn't own, so these are copied, not symlinked —
#     re-run to refresh after you change them).
# The zsh plugins (syntax-highlighting, autosuggestions) are system packages under
# /usr/share, so they already work for root once it's running zsh.
set -euo pipefail

# ── become root, but remember who called us ───────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo "Re-running with sudo (it'll ask for YOUR password)..."
    exec sudo bash "$0" "$@"
fi
# Who to mirror: $SUDO_USER when reached via sudo, else the first argument (handy
# when you're already root via `su -`, where $SUDO_USER isn't set).
CALLER="${SUDO_USER:-${1:-}}"
if [[ -z "$CALLER" || "$CALLER" == root ]]; then
    echo "[ERR] Couldn't tell which user's config to mirror."
    echo "      Run as your normal user:        ./root_shell.sh"
    echo "      …or, if you're already root:     ./root_shell.sh <your-username>   (e.g. Chry)"
    exit 1
fi
if ! getent passwd "$CALLER" >/dev/null; then
    echo "[ERR] No such user: '$CALLER'."; exit 1
fi
CALLER_HOME="$(getent passwd "$CALLER" | cut -d: -f6)"
USER_ZSHRC="$CALLER_HOME/.zshrc"
export HOME=/root   # so Oh-My-Zsh installs into /root, not the caller's home

# ── preconditions ─────────────────────────────────────────────────────────────
ZSH_BIN="$(command -v zsh || true)"
if [[ -z "$ZSH_BIN" ]]; then
    echo "[ERR] zsh isn't installed. Install it first (e.g. your distro's zsh package)."
    exit 1
fi
if [[ ! -f "$USER_ZSHRC" ]]; then
    echo "[ERR] No $USER_ZSHRC to mirror. Deploy/create your zsh config first, then re-run."
    exit 1
fi

# ── 1. zsh must be a valid login shell ────────────────────────────────────────
if ! grep -qxF "$ZSH_BIN" /etc/shells 2>/dev/null; then
    echo "$ZSH_BIN" >> /etc/shells
    echo "[OK] added $ZSH_BIN to /etc/shells"
fi

# ── 2. root's login shell -> zsh ──────────────────────────────────────────────
if [[ "$(getent passwd root | cut -d: -f7)" != "$ZSH_BIN" ]]; then
    chsh -s "$ZSH_BIN" root
    echo "[OK] root's login shell -> $ZSH_BIN"
else
    echo "[OK] root already uses $ZSH_BIN"
fi

# ── 3. Oh-My-Zsh for root (its own install -> no insecure-dir warnings) ────────
if [[ ! -d /root/.oh-my-zsh ]]; then
    echo "Installing Oh-My-Zsh for root..."
    # RUNZSH/CHSH/KEEP_ZSHRC: don't switch shells, don't chsh, don't touch .zshrc.
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended \
        || echo "  (Oh-My-Zsh install failed — check network; your .zshrc still links below)"
else
    echo "[OK] /root/.oh-my-zsh already present"
fi

# ── 4. root's ~/.zshrc -> your ~/.zshrc (symlink keeps them in sync) ───────────
if [[ -e /root/.zshrc && ! -L /root/.zshrc ]]; then
    backup="/root/.zshrc.bak.$(date +%Y%m%d%H%M%S)"
    mv /root/.zshrc "$backup"
    echo "  (backed up root's previous .zshrc -> $backup)"
fi
ln -sfn "$USER_ZSHRC" /root/.zshrc
echo "[OK] /root/.zshrc -> $USER_ZSHRC"

# ── 5. Mirror your other dotfiles so root has the same config ─────────────────
# Symlink the simple ones (nano/git/vim/nvim don't care who owns the file); back up
# any real file already there once, then point root's at yours so edits stay in sync.
# Missing sources are silently skipped.
link_dotfile() {            # $1 = path relative to home, e.g. .nanorc or .config/nvim
    local rel="$1" src="$CALLER_HOME/$1" dst="/root/$1"
    [ -e "$src" ] || return 0
    mkdir -p "$(dirname "$dst")"
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        mv "$dst" "$dst.bak.$(date +%Y%m%d%H%M%S)"
        echo "  (backed up root's previous $rel)"
    fi
    ln -sfn "$src" "$dst"
    echo "[OK] /root/$rel -> $src"
}
for _f in .nanorc .gitconfig .gitconfig_vulnbox .vimrc .config/nvim; do
    link_dotfile "$_f"
done

# ── 6. SSH config + keys for root ─────────────────────────────────────────────
# ssh REFUSES a config/key dir it doesn't own (StrictModes), so these can't be
# symlinked from your home — we COPY them into /root/.ssh as root with safe perms,
# so `ssh <alias>` works as root with your hosts and identity. (root can already read
# your key, so this is no new exposure on a single-admin box.) Re-run this script to
# refresh after you change your ssh config/keys.
if [ -d "$CALLER_HOME/.ssh" ]; then
    mkdir -p /root/.ssh
    for _f in config known_hosts; do
        [ -f "$CALLER_HOME/.ssh/$_f" ] && cp -f "$CALLER_HOME/.ssh/$_f" "/root/.ssh/$_f"
    done
    # Identity keys referenced by `IdentityFile ~/.ssh/...` (now resolve under /root).
    for _k in id_ed25519 id_rsa id_ecdsa; do
        if [ -f "$CALLER_HOME/.ssh/$_k" ]; then
            cp -f "$CALLER_HOME/.ssh/$_k" "/root/.ssh/$_k"
            [ -f "$CALLER_HOME/.ssh/$_k.pub" ] && cp -f "$CALLER_HOME/.ssh/$_k.pub" "/root/.ssh/$_k.pub"
        fi
    done
    chown -R root:root /root/.ssh
    chmod 700 /root/.ssh
    chmod 600 /root/.ssh/config /root/.ssh/id_ed25519 /root/.ssh/id_rsa /root/.ssh/id_ecdsa 2>/dev/null || true
    chmod 644 /root/.ssh/*.pub /root/.ssh/known_hosts 2>/dev/null || true
    echo "[OK] copied your ~/.ssh (config + keys) into /root/.ssh"
fi

echo
echo "Done. Your shell, nano, git, nvim and ssh config now follow you into root."
echo "Try a fresh 'sudo su'. Symlinked configs (zsh/nano/git/nvim) stay in sync with"
echo "your ~/; the ssh config + keys are COPIED — re-run this script to refresh them."
