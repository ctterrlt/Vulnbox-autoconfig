#!/bin/bash
# Master Deployment Script - Run this to choose your target!

echo "========================================"
echo "   VULNBOX MASTER DEPLOYMENT CENTER     "
echo "========================================"

PS3="Select target distribution: "
options=("Arch" "Debian/Ubuntu" "Fedora" "Quit")

select opt in "${options[@]}"; do
    case $opt in
        "Arch")
            ./arch/arch_auto.sh
            break
            ;;
        "Debian/Ubuntu")
            ./debian_ubuntu/debian_ubuntu_auto.sh
            break
            ;;
        "Fedora")
            ./fedora/fedora_auto.sh
            break
            ;;
        "Quit")
            exit 0
            ;;
        *) echo "Invalid option $REPLY";;
    esac
done
