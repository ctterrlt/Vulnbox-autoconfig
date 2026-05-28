# ⚡ Vulnbox-AutoConfig 

A rapid-deployment Zsh configuration toolkit designed for Attack/Defense CTFs, remote server administration, and streamlined terminal environments. 

This project provides automated setup scripts and highly customized `.zshrc` profiles for various Linux distributions. It instantly transforms a barebones remote shell into a fully equipped, passwordless, and visually clean operator environment.

## 🛠️ Key Features
* **Zero-Touch SSH Deployment:** Automatically generates an Ed25519 SSH key (if needed) and deploys it to your target, enabling immediate passwordless access.
* **Pre-Loaded CTF Aliases:** Quick commands for active network sniffing (`sniff`), port checking (`listening`), and IP routing (`myip`).
* **Tactical Tooling:** Built-in alias support for Docker (`dbuild`, `dlog`), Wireguard (`tunnel`), and OpenVPN.
* **Visual & QoL Upgrades:** Pre-configured with Oh-My-Zsh, syntax highlighting, autosuggestions, Fastfetch, and a custom `Chry@Chry` terminal prompt.

---

## 🎯 Target Selection & Usage

**Crucial Rule:** You must always select the configuration folder that matches the Linux distribution of the **remote machine** you are connected to via SSH. 

> **[!] For A/D CTF Players:** > In a competitive environment, this remote machine is your **Vulnbox**. If your Vulnbox is running Ubuntu, use the `ubuntu` directory. Do not use your local machine's OS.

### Supported Distributions
* `arch/` - Arch Linux & derivatives
* `fedora/` - Fedora & RHEL-based systems
* `debian_ubuntu/` - Ubuntu & Debian-based systems

### Quick Start
1. Clone this repository to your local machine.
2. Navigate into the folder matching your target's OS:
   ```bash
   cd ubuntu # Or arch/fedora depending on the target
