# 🚀 Vulnbox-AutoConfig

A unified, professional-grade deployment framework for Attack/Defense CTFs and remote administration. This toolkit transforms bare-bones remote shells into fully-equipped, custom-configured operator environments in seconds.

## 🌟 Key Features

- **Master Controller:** One-click deployment from a central hub.
- **Standardized Workflow:** All distributions use a single `zshconfig` source-of-truth.
- **Global Git Configuration:** Automatically links a shared repository of Git aliases and visual tweaks, prompting for identity setup if needed, without destroying existing configurations.
- **Zero-Touch SSH:** Automatically handles SSH key generation and target authentication.
- **Custom Port Support:** Prompts for the target SSH port (defaults to 22 if left empty).
- **Auto SSH Config:** Writes a `~/.ssh/config` entry for each target so you can `ssh <alias>` after deployment without remembering IPs or ports.
- **CTF Ready:** Pre-loaded aliases for Docker, networking, VPNs, and offensive toolchains.
- **Visual & QoL:** Pre-configured with Fastfetch, Oh-My-Zsh, syntax highlighting, and autosuggestions.
- **Automatic Backup:** Automatically zips everything on the vulnbox.

---

## 📂 Repository Structure

The repository is organized by distribution. Each folder contains the specific automation logic for that OS, sharing a standardized configuration file.

```text
.
├── auto.sh                       # <-- Run this to start
├── gitconfig.conf                # Shared Git aliases and core settings
├── sshconf.sh                    # Shared SSH setup (prompts, ~/.ssh/config, key gen/copy)
├── arch/
│   ├── arch_auto.sh              # Deployment script
│   ├── zshchangeconf_arch.sh     # Re-push config only (no full redeploy)
│   └── zshconfig_arch.conf       # Arch-specific zsh config
├── debian_ubuntu/
│   ├── debian_ubuntu_auto.sh
│   ├── zshchangeconf_debian_ubuntu.sh
│   └── zshconfig_debian_ubuntu.conf
└── fedora/
    ├── fedora_auto.sh
    ├── zshchangeconf_fedora.sh
    └── zshconfig_fedora.conf
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

1. **Git Setup:** Upon first run, the master script will link your `gitconfig.conf` aliases and prompt you for your Git `user.name` and `user.email` if they aren't already set on your local machine.
2. **Select Target:** Choose the distribution that matches your remote target (Arch, Debian/Ubuntu, or Fedora).
3. **Authentication:** Enter the remote IP, username, SSH port (leave blank for 22), and an optional friendly alias for the host.
4. **Automation:** The script will automatically:
   - Add a `~/.ssh/config` entry for the target (alias, IP, port, identity file) so you can reconnect later with just `ssh <alias>`.
   - Generate local SSH keys (if missing).
   - Upload the public key to the remote box.
   - Upload the zsh config file to the remote `/tmp`.
   - Execute the remote payload to install packages and apply the configuration.
   - Drop you into your new Zsh environment.

> **Tip:** If your SSH key is already deployed on the target, you can skip the key-gen and key-copy step by running `SKIP_SSH=1 ./auto.sh`. The IP/user/port prompts still run — they're needed for the rest of the deploy.

---

## 💡 Maintenance

To update your environment (e.g., changing an alias or adding a tool):

1. **For Shell Aliases:** Navigate to the specific distro folder (e.g., `cd arch/`) and edit the `zshconfig_arch.conf` file.
2. **For Git Aliases:** Edit the global `gitconfig.conf` file in the root directory.
3. **For SSH Setup** (key generation, key copy, `~/.ssh/config` entry): edit the single root `sshconf.sh` — all distros share it.
4. **That's it.** The next time you run `./auto.sh`, it will push the updated configurations automatically. You never need to touch the deploy script logic again.

---

## ⚠️ Safety Warning

- **Local Execution Only:** This tool is designed to be run from your **local PC**, not on the target remote machine.
- **Safety Guards:** Every script includes a check to ensure you aren't running it inside a Docker container or from the wrong directory by accident. Always heed the **DANGER** warnings if they appear.

---

Happy Hacking! 🛡✨
