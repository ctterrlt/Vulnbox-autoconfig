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
#   * links /root/.zshrc -> your ~/.zshrc    so future edits stay in sync
#                                            (undo: sudo rm /root/.zshrc)
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

echo
echo "Done. Your config now follows you into root — try a fresh 'sudo su'."
echo "Edits to $USER_ZSHRC apply to root too (it's a symlink)."
