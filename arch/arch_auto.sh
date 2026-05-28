#!/bin/bash
# ==============================================================================
# VULNBOX AUTO-DEPLOYMENT SCRIPT
# RUN THIS ON YOUR LOCAL PC
# ==============================================================================

# Safety Guard
if [ -f /.dockerenv ] || [ "$USER" == "root" ]; then
    echo "WARNING: This script is intended to be run from your LOCAL PC."
    read -p "Are you sure? (y/N) " confirm
    [[ $confirm != [yY] ]] && exit 1
fi

echo -e "\n=== 🎯 TARGET CONFIGURATION ==="
read -p "Enter target remote IP: " TARGET_IP
read -p "Enter target remote username: " TARGET_USER

# --- 1. SECURE ACCESS ---
echo -e "\n=== 🔐 1. SECURING ACCESS ==="
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
fi
ssh-copy-id -i ~/.ssh/id_ed25519.pub "${TARGET_USER}@${TARGET_IP}"

# --- 2. UPLOAD CONFIG ---
echo -e "\n=== 📤 2. UPLOADING CONFIG ==="
# We copy the config file to the remote /tmp folder NOW, from your Local PC
scp zshconfig_arch.conf "${TARGET_USER}@${TARGET_IP}:/tmp/zshconfig_arch.conf"

# --- 3. GENERATE AND SHIP PAYLOAD ---
echo -e "\n=== 🚀 3. DEPLOYING PAYLOAD ==="
cat << 'PAYLOAD_EOF' > /tmp/vulnbox_payload.sh
#!/bin/bash
# This runs on the REMOTE machine

# Install Packages
sudo pacman -Syu --needed zip zsh nano git curl fastfetch lsd tty-clock cmatrix zsh-syntax-highlighting zsh-autosuggestions openssh

# Install Oh-My-Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Change default shell
sudo chsh -s $(which zsh) $USER

# Apply the config we uploaded earlier
mv /tmp/zshconfig_arch.conf ~/.zshrc

echo "Configuration applied successfully."
PAYLOAD_EOF

# Copy the setup script and execute it
scp /tmp/vulnbox_payload.sh "${TARGET_USER}@${TARGET_IP}:/tmp/setup.sh"
ssh -t "${TARGET_USER}@${TARGET_IP}" "bash /tmp/setup.sh && rm /tmp/setup.sh && exec zsh"
