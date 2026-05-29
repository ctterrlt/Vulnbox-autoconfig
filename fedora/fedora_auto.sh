#!/bin/bash
# VULNBOX AUTO-DEPLOYMENT SCRIPT (FEDORA)

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. SAFETY & INPUT
if [ -f /.dockerenv ] || [ "$USER" == "root" ]; then
    echo "WARNING: This script is intended to be run from your LOCAL PC."
    read -p "Are you sure? (y/N) " confirm
    [[ $confirm != [yY] ]] && exit 1
fi

echo -e "\n=== TARGET CONFIGURATION ==="
read -p "Enter target remote IP: " TARGET_IP
read -p "Enter target remote username: " TARGET_USER

# 2. SECURE ACCESS
echo -e "\n=== 1. SECURING ACCESS ==="
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
fi
ssh-copy-id -i ~/.ssh/id_ed25519.pub "${TARGET_USER}@${TARGET_IP}"

# 3. GENERATE PAYLOAD
echo -e "\n=== 2. DEPLOYING PAYLOAD ==="

cat << 'PAYLOAD_EOF' > /tmp/vulnbox_payload.sh
#!/bin/bash
# This block is executed ON THE REMOTE MACHINE

# Install Packages (Fedora Specific)
sudo dnf install -y zip zsh nano git curl fastfetch lsd tty-clock cmatrix openssh-server
# Note: Fedora repos often handle zsh-syntax-highlighting differently; 
# Oh-My-Zsh plugins are usually the safest way to manage these.

# Install Oh-My-Zsh (Non-interactive)
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Change default shell
sudo chsh -s $(which zsh) "$USER"

# Apply Config (Ensure this filename matches your local file)
mv /tmp/zshconfig_fedora.conf ~/.zshrc

# Backup
rm -f ~/backup.zip
zip -r ~/backup.zip ~ -x 'backup.zip'

echo "Deployment complete."
PAYLOAD_EOF

# 4. TRANSFER & EXECUTE
# SCP the config and the generated payload
scp "$DIR/zshconfig_fedora.conf" "${TARGET_USER}@${TARGET_IP}:/tmp/zshconfig_fedora.conf"
scp /tmp/vulnbox_payload.sh "${TARGET_USER}@${TARGET_IP}:/tmp/setup.sh"

# Execute remotely (Wait for setup to finish, then delete payload)
echo "Running remote setup..."
ssh "${TARGET_USER}@${TARGET_IP}" "bash /tmp/setup.sh && rm /tmp/setup.sh"

# Pull the backup file to your local directory
echo "Pulling backup to local machine..."
scp "${TARGET_USER}@${TARGET_IP}:~/backup.zip" "$DIR/backup_from_${TARGET_IP}.zip"

# Finally, drop into the remote shell
echo "Deployment complete. Logging you in..."   
ssh -t "${TARGET_USER}@${TARGET_IP}" "exec zsh"
