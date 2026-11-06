#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Standalone manual install — runs ON the target box.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# openssh-clients: for SSH-ing OUT from this box (vs openssh-server in the auto deploy payload).
# zsh-syntax-highlighting/zsh-autosuggestions included here; the auto deploy payload omits them (handled via OMZ plugins instead).
# Core packages first; cosmetic extras via --skip-unavailable so a missing/dead one
# (neofetch is discontinued, tty-clock isn't always packaged) is dropped instead of
# aborting the install.
sudo dnf update -y
# php: runtime for the PHP-based web exploits (python_exploits/web/ccalendar_*).
sudo dnf install -y zip zsh nano git curl zsh-syntax-highlighting zsh-autosuggestions openssh-clients php
sudo dnf install -y --skip-unavailable fastfetch lsd tty-clock cmatrix
if [[ -e "$HOME/.zshrc" || -L "$HOME/.zshrc" ]]; then
    cp -a "$HOME/.zshrc" "$HOME/.zshrc.vulnbox-backup.$(date +%Y%m%d%H%M%S)"
fi
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
sudo chsh -s "$(which zsh)" "$USER"
install -m 644 "$DIR/zshconfig_fedora.conf" "$HOME/.zshrc"
bash "$DIR/../install_bash_config.sh" "$DIR/bashconfig_fedora.conf"
exec zsh
