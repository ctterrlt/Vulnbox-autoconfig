# ⚡ Vulnbox-AutoConfig

A rapid-deployment Zsh configuration toolkit designed for Attack/Defense CTFs, remote server administration, and streamlined terminal environments.

This project provides automated setup scripts and highly customized `.zshrc` profiles for various Linux distributions. It instantly transforms a barebones remote shell into a fully equipped, passwordless, and visually clean operator environment.

## 🛠️ Key Features
* **Zero-Touch SSH Deployment:** Automatically generates an Ed25519 SSH key (if needed) and deploys it to your target.
* **Pre-Loaded CTF Aliases:** Quick commands for network sniffing (`sniff`), port checking (`listening`), and IP routing (`myip`).
* **Tactical Tooling:** Built-in alias support for Docker (`dbuild`, `dlog`), Wireguard (`tunnel`), and OpenVPN.
* **Visual & QoL Upgrades:** Pre-configured with Oh-My-Zsh, syntax highlighting, autosuggestions, Fastfetch, and a custom `USER@IP/DEVICE` terminal prompt.

---

## 🎯 Target Selection & Usage

**Crucial Rule:** Always select the configuration folder that matches the Linux distribution of the **remote machine** you are connected to via SSH.

> **[!] For A/D CTF Players:** In a competitive environment, this remote machine is your **Vulnbox**. Do not use your local machine's OS; use the OS of the target.

### Supported Distributions
* `arch/` - Arch Linux & derivatives
* `fedora/` - Fedora & RHEL-based systems
* `debian_ubuntu/` - Ubuntu & Debian-based systems

## 🚀 Deployment Methods

### 1. Automatic Deployment (Recommended)
Best for rapid deployment from your local machine. This pushes keys, installs packages, applies configs, and drops you into a fresh Zsh session.
1. `cd` into your target folder (e.g., `cd debian_ubuntu`).
2. Run `chmod +x *.sh` to set permissions.
3. Run the auto-deploy script: `./<distro>_auto.sh`

### 2. Manual Deployment (Granular Control)
Use this for step-by-step builds:
* **`s` scripts:** Execute these **on the remote Vulnbox**.
* **`b` scripts:** Execute these **on your local computer**.

---

## ⚠️ Critical Rule
* **Always check your context:** Running a script labeled for `s` (server) on your local machine might unintentionally change your local shell or overwrite your personal config.
* **Permissions:** Always run `chmod +x *.sh` in the directory before attempting to execute scripts.
