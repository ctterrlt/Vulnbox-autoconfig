#!/bin/bash
# ==============================================================================
# FEDORA AUTO-DEPLOYMENT SCRIPT
# RUN THIS ON YOUR LOCAL PC
# ==============================================================================

if [ -f /.dockerenv ] || [ "$USER" == "root" ]; then
    echo "WARNING: This script is intended to be run from your LOCAL PC."
    read -p "Are you sure you want to proceed? (y/N) " confirm
    [[ $confirm != [yY] ]] && exit 1
fi

echo -e "\n=== 🎯 TARGET CONFIGURATION ==="
read -p "Enter target remote IP: " TARGET_IP
read -p "Enter target remote username: " TARGET_USER

# --- 1. SECURE ACCESS ---
ssh-copy-id -i "$HOME/.ssh/id_ed25519.pub" "${TARGET_USER}@${TARGET_IP}"

# --- 2. UPLOAD CONFIG (Local Machine) ---
echo -e "\n=== 📤 2. UPLOADING CONFIG ==="
if [ -f "zshconfig_fedora.conf" ]; then
    # We copy the file NOW, while we are still on the local machine
    scp zshconfig_fedora.conf "${TARGET_USER}@${TARGET_IP}:/tmp/zshconfig_fedora.conf"
else
    echo "Error: zshconfig_fedora.conf not found!"
    exit 1
fi

# --- 3. GENERATE THE PAYLOAD (Local Machine) ---
echo -e "\n=== 🚀 3. PREPARING PAYLOAD ==="
cat << 'PAYLOAD_EOF' > /tmp/vulnbox_payload_fed.sh
#!/bin/bash
# Everything below happens on the REMOTE machine

# Install Packages
sudo dnf update -y && sudo dnf install -y zip zsh nano git curl fastfetch lsd tty-clock cmatrix zsh-syntax-highlighting zsh-autosuggestions openssh-clients

# Install Oh-My-Zsh (Unattended)
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Change default shell
sudo chsh -s $(which zsh) $USER

# Apply the config
# The file was uploaded to /tmp earlier by the local script
mv /tmp/zshconfig_fedora.conf ~/.zshrc

echo -e "\n=== ✅ FEDORA ENVIRONMENT DEPLOYED SUCCESSFULLY ==="
PAYLOAD_EOF

# --- 4. SHIP IT AND RUN IT ---
echo -e "\n=== 🚚 4. DEPLOYING TO TARGET ==="
scp /tmp/vulnbox_payload_fed.sh "${TARGET_USER}@${TARGET_IP}:/tmp/setup.sh"
ssh -t "${TARGET_USER}@${TARGET_IP}" "bash /tmp/setup.sh && rm /tmp/setup.sh && exec zsh"
