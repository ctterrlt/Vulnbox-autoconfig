#!/bin/bash
# Standalone manual install — runs ON the target box.
# openssh-clients: for SSH-ing OUT from this box (vs openssh-server in the auto deploy payload).
# zsh-syntax-highlighting/zsh-autosuggestions included here; the auto deploy payload omits them (handled via OMZ plugins instead).
# Core packages first; cosmetic extras via --skip-unavailable so a missing/dead one
# (neofetch is discontinued, tty-clock isn't always packaged) is dropped instead of
# aborting the install.
sudo dnf update -y
sudo dnf install -y zip zsh nano git curl zsh-syntax-highlighting zsh-autosuggestions openssh-clients
sudo dnf install -y --skip-unavailable fastfetch lsd tty-clock cmatrix
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
sudo chsh -s "$(which zsh)" "$USER"
exec zsh
