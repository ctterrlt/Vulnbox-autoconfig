#!/bin/bash
#debian_ubuntu
sudo apt update && sudo apt install -y zip zsh git curl neofetch lsd tty-clock cmatrix zsh-syntax-highlighting zsh-autosuggestions openssh-client && sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended && sudo chsh -s $(which zsh) $USER && exec zsh
