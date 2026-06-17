#!/bin/bash
# Standalone manual install — runs ON the target box.
# Keep package list aligned with arch_auto.sh payload.
set -euo pipefail

# Bootstrap yay if not present
if ! command -v yay &>/dev/null; then
    sudo pacman -Sy --noconfirm --needed base-devel git
    tmpdir=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
    if [[ $EUID -eq 0 ]]; then
        useradd -M -s /bin/bash _aurbuild 2>/dev/null || true
        chown -R _aurbuild: "$tmpdir/yay"
        echo "_aurbuild ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/_aurbuild
        sudo -u _aurbuild bash -c "cd '$tmpdir/yay' && makepkg -si --noconfirm"
        rm -f /etc/sudoers.d/_aurbuild
        userdel _aurbuild 2>/dev/null || true
    else
        (cd "$tmpdir/yay" && makepkg -si --noconfirm)
    fi
    rm -rf "$tmpdir"
fi

# Core packages first; cosmetic extras best-effort so a missing one can't abort.
yay -Syu --noconfirm --needed zip zsh nano git curl zsh-syntax-highlighting zsh-autosuggestions openssh
for _pkg in fastfetch lsd tty-clock cmatrix; do
    yay -S --noconfirm --needed "$_pkg" || echo "  (skipped $_pkg — not available in repos)"
done
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
sudo chsh -s "$(which zsh)" "$USER"
exec zsh
