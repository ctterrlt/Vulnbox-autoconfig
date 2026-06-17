#!/bin/bash
#debian_ubuntu
# Standalone manual install — runs ON the target box.
# openssh-client: for SSH-ing OUT from this box (vs openssh-server in the auto deploy payload).
# Keep package list aligned with debian_ubuntu_auto.sh payload.
# Core packages first; cosmetic extras best-effort so a missing/dead one (neofetch
# is discontinued, fastfetch/tty-clock aren't in every release) can't abort the install.
sudo apt update
sudo apt install -y zip zsh nano git curl zsh-syntax-highlighting zsh-autosuggestions openssh-client
for _pkg in fastfetch lsd tty-clock cmatrix; do
    sudo apt install -y "$_pkg" || echo "  (skipped $_pkg — not in repos)"
done
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
sudo chsh -s "$(which zsh)" "$USER"
exec zsh
