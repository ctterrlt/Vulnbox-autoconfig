#!/bin/bash
#debian_ubuntu
# Standalone manual install — runs ON the target box.
# openssh-client: for SSH-ing OUT from this box (vs openssh-server in the auto deploy payload).
# Keep package list aligned with debian_ubuntu_auto.sh payload.
sudo apt update && sudo apt install -y zip zsh nano git curl neofetch lsd tty-clock cmatrix zsh-syntax-highlighting zsh-autosuggestions openssh-client && sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended && sudo chsh -s $(which zsh) $USER && exec zsh
