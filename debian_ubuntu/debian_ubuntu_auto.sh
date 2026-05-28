#!/bin/bash
# ==============================================================================
# DEBIAN/UBUNTU AUTO-DEPLOYMENT SCRIPT
# RUN THIS ON YOUR LOCAL PC
# ==============================================================================

# Safety Guard: Check if we are running locally (not on a server/docker)
if [ -f /.dockerenv ] || [ "$USER" == "root" ]; then
    echo "WARNING: This script is intended to be run from your LOCAL PC."
    read -p "Are you sure you want to proceed? (y/N) " confirm
    [[ $confirm != [yY] ]] && exit 1
fi

echo -e "\n=== 🎯 TARGET CONFIGURATION ==="
read -p "Enter target remote IP: " TARGET_IP
read -p "Enter target remote username: " TARGET_USER

# --- 1. SECURE ACCESS (SSH KEYS) ---
echo -e "\n=== 🔐 1. SECURING ACCESS ==="
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    echo "Generating new passwordless SSH key..."
    ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
fi

echo "Copying key to target (You may need to type the password one last time)..."
ssh-copy-id -i "$HOME/.ssh/id_ed25519.pub" "${TARGET_USER}@${TARGET_IP}"

# --- 2. UPLOAD CONFIG ---
echo -e "\n=== 📤 2. UPLOADING CONFIG ==="
if [ -f "zshconfig_debian_ubuntu.conf" ]; then
    scp zshconfig_debian_ubuntu.conf "${TARGET_USER}@${TARGET_IP}:/tmp/zshconfig_debian_ubuntu.conf"
else
    echo "Error: zshconfig_debian_ubuntu.conf not found in the current directory!"
    exit 1
fi

# --- 3. PREPARE PAYLOAD ---
echo -e "\n=== 🚀 3. DEPLOYING PAYLOAD ==="
cat << 'PAYLOAD_EOF' > /tmp/vulnbox_payload_deb.sh
#!/bin/bash
# This runs on the REMOTE machine

# Update and Install Packages
sudo apt update && sudo apt install -y \
    zip zsh git curl lsd tty-clock cmatrix openssh-client \
    zsh-syntax-highlighting zsh-autosuggestions

# Install Oh-My-Zsh (Unattended)
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Change default shell
sudo chsh -s $(which zsh) $USER

# Apply the config
mv /tmp/zshconfig_debian_ubuntu.conf ~/.zshrc

echo -e "\n=== ✅ DEBIAN/UBUNTU DEPLOYED SUCCESSFULLY ==="
PAYLOAD_EOF

# --- 4. SHIP IT AND RUN IT ---
scp /tmp/vulnbox_payload_deb.sh "${TARGET_USER}@${TARGET_IP}:/tmp/setup.sh"
ssh -t "${TARGET_USER}@${TARGET_IP}" "bash /tmp/setup.sh && rm /tmp/setup.sh && exec zsh"
