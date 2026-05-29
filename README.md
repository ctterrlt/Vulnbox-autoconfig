# 🚀 Vulnbox-AutoConfig

A unified, professional-grade deployment framework for Attack/Defense CTFs and remote administration. This toolkit transforms bare-bones remote shells into fully-equipped, custom-configured operator environments in seconds.

## 🌟 Key Features

- **Master Controller:** One-click deployment from a central hub.
- **Standardized Workflow:** All distributions use a single `zsh.conf` source-of-truth.
- **Zero-Touch SSH:** Automatically handles SSH key generation and target authentication.
- **CTF Ready:** Pre-loaded aliases for Docker, networking, VPNs, and offensive toolchains.
- **Visual & QoL:** Pre-configured with Fastfetch, Oh-My-Zsh, syntax highlighting, and autosuggestions.
- **Automatic Backup:** Automatically zips everything on the vulnbox.

---

## 📂 Repository Structure

The repository is organized by distribution. Each folder contains the specific automation logic for that OS, sharing a standardized configuration file.

```text
.
├── auto.sh                 # <-- Run this to start
├── arch/
│   ├── arch_auto.sh        # Deployment script
│   └── zsh.conf            # Arch-specific config
├── debian_ubuntu/
│   ├── debian_ubuntu_auto.sh
│   └── zsh.conf            # Debian/Ubuntu-specific config
└── fedora/
    ├── fedora_auto.sh
    └── zsh.conf            # Fedora-specific config
```

---

## 🚀 How to Deploy

### 1. Initial Setup

Ensure all scripts are executable before running the master controller:

```bash
chmod +x auto.sh
find . -name "*.sh" -exec chmod +x {} \;
```

### 2. Execution

From the repo root directory, run the master script:

```bash
./auto.sh
```

### 3. Usage Steps

1. **Select Target:** Choose the distribution that matches your remote target (Arch, Debian/Ubuntu, or Fedora).
2. **Authentication:** Enter the remote IP and username.
3. **Automation:** The script will automatically:
   - Generate local SSH keys (if missing).
   - Upload the public key to the remote box.
   - Upload the `zsh.conf` file to the remote `/tmp`.
   - Execute the remote payload to install packages and apply the configuration.
   - Drop you into your new Zsh environment.

---

## 💡 Maintenance

To update your environment (e.g., changing an alias or adding a tool):

1. Navigate to the specific distro folder (e.g., `cd arch/`).
2. Edit the `zsh.conf` file.
3. That's it. The next time you run `./auto.sh`, it will push the updated configuration automatically. You never need to touch the `.sh` script logic again.

---

## ⚠️ Safety Warning

- **Local Execution Only:** This tool is designed to be run from your **local PC**, not on the target remote machine.
- **Safety Guards:** Every script includes a check to ensure you aren't running it inside a Docker container or from the wrong directory by accident. Always heed the **DANGER** warnings if they appear.

---

Happy Hacking! 🛡✨
