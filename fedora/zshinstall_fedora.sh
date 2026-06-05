#!/bin/bash
# Standalone manual install — runs ON the target box.
# openssh-clients: for SSH-ing OUT from this box (vs openssh-server in the auto deploy payload).
# zsh-syntax-highlighting/zsh-autosuggestions included here; the auto deploy payload omits them (handled via OMZ plugins instead).
sudo dnf update -y && sudo dnf install -y zip zsh nano git curl neofetch lsd tty-clock cmatrix zsh-syntax-highlighting zsh-autosuggestions openssh-clients && sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended && sudo chsh -s $(which zsh) $USER && exec zsh
