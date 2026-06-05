#!/bin/bash
#arch
yay -Syu --noconfirm --needed zip zsh nano git curl fastfetch lsd tty-clock cmatrix zsh-syntax-highlighting zsh-autosuggestions openssh && sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended && sudo chsh -s $(which zsh) $USER && exec zsh
