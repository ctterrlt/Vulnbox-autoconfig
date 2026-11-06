#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Standalone manual install — runs ON the target box.
# Keep package list aligned with arch_auto.sh payload.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Core packages first; cosmetic extras best-effort so a missing one can't abort.
# php: runtime for the PHP-based web exploits (python_exploits/web/ccalendar_*).
sudo pacman -Syu --noconfirm --needed zip zsh nano git curl zsh-syntax-highlighting zsh-autosuggestions openssh php
for _pkg in fastfetch lsd cmatrix; do
    sudo pacman -S --noconfirm --needed "$_pkg" || echo "  (skipped $_pkg — not available in repos)"
done
if [[ -e "$HOME/.zshrc" || -L "$HOME/.zshrc" ]]; then
    cp -a "$HOME/.zshrc" "$HOME/.zshrc.vulnbox-backup.$(date +%Y%m%d%H%M%S)"
fi
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
sudo chsh -s "$(which zsh)" "$USER"
install -m 644 "$DIR/zshconfig_arch.conf" "$HOME/.zshrc"
bash "$DIR/../install_bash_config.sh" "$DIR/bashconfig_arch.conf"
exec zsh
