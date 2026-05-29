# 🚀 Vulnbox-AutoConfig

A unified, professional-grade deployment framework for Attack/Defense CTFs and remote administration. This toolkit transforms bare-bones remote shells into fully-equipped, custom-configured operator environments in seconds.

## 🌟 Key Features

* **Master Controller:** One-click deployment from a central hub.
* **Standardized Workflow:** All distributions use a single `zsh.conf` source-of-truth.
* **Zero-Touch SSH:** Automatically handles SSH key generation and target authentication.
* **CTF Ready:** Pre-loaded aliases for Docker, networking, VPNs, and offensive toolchains.
* **Visual & QoL:** Pre-configured with Fastfetch, Oh-My-Zsh, syntax highlighting, and autosuggestions.

---

## 📂 Repository Structure

The repository is organized by distribution. Each folder contains the specific automation logic for that OS, sharing a standardized configuration file.

```text
.
├── auto_deploy.sh          # <-- Run this to start
├── arch/
│   ├── arch_auto.sh        # Deployment script
│   └── zsh.conf            # Arch-specific config
├── debian_ubuntu/
│   ├── debian_ubuntu_auto.sh
│   └── zsh.conf            # Debian/Ubuntu-specific config
└── fedora/
    ├── fedora_auto.sh
    └── zsh.conf            # Fedora-specific config

🚀 How to Deploy
1. Initial Setup

Ensure all scripts are executable before running the master controller:
Bash

chmod +x auto_deploy.sh
find . -name "*.sh" -exec chmod +x {} \;

2. Execution

From the root directory, run the master script:
Bash

./auto_deploy.sh

3. Usage Steps

    Select Target: Choose the distribution that matches your remote target (Arch, Debian/Ubuntu, or Fedora).

    Authentication: Enter the remote IP and username.

    Automation: The script will automatically:

        Generate local SSH keys (if missing).

        Upload the public key to the remote box.

        Upload the zsh.conf file to the remote /tmp.

        Execute the remote payload to install packages and apply the configuration.

        Drop you into your new Zsh environment.

💡 Maintenance

To update your environment (e.g., changing an alias or adding a tool):

    Navigate to the specific distro folder (e.g., cd arch/).

    Edit the zsh.conf file.

    That's it. The next time you run auto_deploy.sh, it will push the updated configuration automatically. You never need to touch the .sh script logic again.

⚠️ Safety Warning

    Local Execution Only: This tool is designed to be run from your Local PC, not on the target remote machine.

    Safety Guards: Every script includes a check to ensure you aren't running it on a live production server or inside a docker container by accident. Always heed the "DANGER" warnings if they appear.

Happy Hacking! 🛡✨
