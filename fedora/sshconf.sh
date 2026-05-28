# standard one-liner to use later
# standard one-liner to use later
echo -e "\n===  ^=^l^p LOCAL NETWORK INTERFACES ==="
ip -br addr

echo -e "\n===  ^=^n  TARGET CONFIGURATION ==="
echo -n "Enter target remote IP (or press Enter to skip): "
read TARGET_IP

if [ -n "$TARGET_IP" ]; then
    echo -n "Enter target remote username: "
    read TARGET_USER

    echo -e "\n===  ^=^t^q DEPLOYING SSH KEY ==="
    
    # 1. Check if the key already exists to prevent overwriting
    if [ -f "$HOME/.ssh/id_ed25519" ]; then
        echo "Existing SSH key found at ~/.ssh/id_ed25519. Skipping generation."
    else
        echo "No SSH key found. Generating a new passwordless Ed25519 key..."
        ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
    fi

    # 2. Copy the public key to the target machine
    echo "Copying key to ${TARGET_USER}@${TARGET_IP}..."
    ssh-copy-id -i ~/.ssh/id_ed25519.pub "${TARGET_USER}@${TARGET_IP}" || \
    (cat ~/.ssh/id_ed25519.pub | ssh "${TARGET_USER}@${TARGET_IP}" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys")
else
    echo "Skipping SSH deployment."
fi


