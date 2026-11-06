<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->
<!-- Purpose: Fedora automated remote deployment guide and maintenance reference. -->

# 👒 Fedora Vulnbox AutoConfig

[![License: AGPL-3.0-or-later](https://img.shields.io/badge/license-AGPL--3.0--or--later-blue?style=flat-square)](../LICENSE)
[![Platform: Fedora](https://img.shields.io/badge/platform-Fedora-51A2DA?style=flat-square&logo=fedora&logoColor=white)](https://fedoraproject.org)
[![Shell: Zsh](https://img.shields.io/badge/shell-zsh%20%7C%20oh--my--zsh-orange?style=flat-square)](../README.md)

Automated remote deployment suite for provisioning, configuring, and hardening **Fedora** and **RHEL-based** targets over SSH. Built for Attack/Defense CTFs to transform fresh or reset instances into operational operator environments in seconds.

> **Execution Boundary:** Run the remote deployment scripts locally. The standalone `zshinstall_fedora.sh` runs on the Fedora host it configures.

---

## Deployment Modes

### 1. Master Menu (Recommended)
From the repository root:
```bash
./auto.sh        # Select "Fedora" from the interactive menu
```
The master orchestrator handles Git configuration imports, refreshes exploit dependencies, and transitions directly into the Fedora deployment flow.

### 2. Direct Distro Execution
Bypass the top-level menu to target Fedora directly:
```bash
cd fedora && ./fedora_auto.sh
```

> [!TIP]
> If your SSH key is already installed on the target, skip key generation and distribution:
> ```bash
> SKIP_SSH=1 ./fedora_auto.sh
> ```

---

## Interactive Deployment Pipeline

The Fedora deployment routine executes the following phases in sequence:

1. **SSH Target Resolution (`sshconf.sh`):** Discovers existing `~/.ssh/config` hosts via `ssh -G` or prompts for IP, user, port (default `22`), and an alias, creating persistent configuration.
2. **SCP Transport Mode:** Prompts for legacy SCP (`-O`, default) vs. SFTP to prevent channel errors on stripped remote SSH daemons.
3. **Key Distribution (`selectlib.sh`):** Interactive toggle for `~/.ssh/id_ed25519.pub` and optional team keys from the local, gitignored `../extra_keys.pub` (seeded empty from [`extra_keys.pub.example`](../extra_keys.pub.example); add intended keys locally). Appends keys atomically with remote `chmod 700 ~/.ssh` and `chmod 600 authorized_keys`.
4. **Local Exploit Dependencies (`y/N`):** Optionally runs `pip install -r requirements.txt` on your operator machine.
5. **Neovim Configuration (`y/N`):** Deploys [`nvimconfig.lua`](../nvimconfig.lua) to `~/.config/nvim/init.lua` and ensures `neovim` is installed.
6. **Git Aliases (`y/N`):** Deploys [`gitconfig.conf`](../gitconfig.conf) to `~/.gitconfig_vulnbox` and links it via `include.path`.
7. **Defensive TLS Bridge (`y/N`):** Copies [`python_exploits/tls`](../python_exploits/tls) to `~/tls_bridge` on the target for traffic inspection.
8. **nano Configuration (`y/N`):** Deploys [`nanorc`](../nanorc) to `~/.nanorc` with syntax highlighting and sane indentation.
9. **Konsole Profile & Shortcuts (`y/N`):** Deploys [`konsolerc`](../konsolerc) and [`konsole.profile`](../konsole.profile) with automated background shortcut sync.
10. **SSH Daemon Hardening (`y/N`):** Validates and installs [`sshd_00-custom-ssh.conf`](../sshd_00-custom-ssh.conf) at `/etc/ssh/sshd_config.d/00-custom-ssh.conf`. It allows the active connection port plus 22222 and disables password/root login; confirm key access first.
11. **nftables Firewall (`y/N`):** Adds a dedicated strict-input table to the Fedora nftables service config (`/etc/sysconfig/nftables.conf`) with VPN interface allowlisting (`wt0`, `tailscale0`, `100.64.0.0/10`). This can block the current connection and other inbound services.
12. **Fail2ban Jail (`y/N`):** Validates and installs [`fail2ban_jail.local`](../fail2ban_jail.local) with the systemd backend and one-hour bans for SSH on port 22222 plus the active target port.
13. **sysctl Hardening (`y/N`):** Deploys [`sysctl_90-no-ping.conf`](../sysctl_90-no-ping.conf) to `/etc/sysctl.d/90-no-ping.conf` to suppress ICMP echo replies.
14. **Target Root Shell (`Y/n`, default yes):** Ships [`root_shell.sh`](../root_shell.sh) so `sudo su` mirrors Zsh/Bash aliases and selected dotfiles; configured SSH identities are copied into `/root/.ssh`.
15. **Dev Repository Clone (`y/N`):** Clones this toolkit onto the box via HTTPS for remote debugging.
16. **Remote Backup (`y/N`):** Interactively inspects remote directories, creates `backup.zip`, and downloads it as `backup_from_<IP>.zip` (with a numeric suffix if that file exists).

The deployment also installs `bashconfig_fedora.conf` as `~/.bashrc_vulnbox` and enables it through a managed block in an existing regular `~/.bashrc`.

---

## Package Provisioning

Fedora provisioning utilizes `dnf` with non-interactive defaults:
- **Core Packages:** `zip`, `zsh`, `nano`, `git`, `curl`, `zsh-syntax-highlighting`, `zsh-autosuggestions`, `openssh-server`, and `php` (required for PHP-based web exploit helpers).
- **Cosmetic Utilities (Best-Effort):** `fastfetch`, `lsd`, `tty-clock`, and `cmatrix` installed in a single transaction via `dnf install -y --skip-unavailable`.
- **Path Hardening:** Deployed `.zshrc` dynamically prepends `/usr/local/sbin`, `/usr/sbin`, and `/sbin` to `$PATH`.

---

## Alternative Entry Points

- **Configuration Re-Push (No Reinstall):**
  ```bash
  ./zshchangeconf_fedora.sh
  ```
- **Local Standalone Installer (Run directly on a Fedora host):**
  ```bash
  ./zshinstall_fedora.sh
  ```

---

## Maintenance & File Mapping

| Component | Target File | Repository Source |
| :--- | :--- | :--- |
| Shell Configuration | `~/.zshrc` | `zshconfig_fedora.conf` |
| Bash Aliases | `~/.bashrc_vulnbox` and managed source block in `~/.bashrc` | `bashconfig_fedora.conf` via `../install_bash_config.sh` |
| Neovim Config | `~/.config/nvim/init.lua` | `../nvimconfig.lua` |
| Git Aliases | `~/.gitconfig_vulnbox` | `../gitconfig.conf` |
| nano Config | `~/.nanorc` | `../nanorc` |
| Konsole Shortcuts | `~/.config/konsolerc` | `../konsolerc` |
| SSH Hardening | `/etc/ssh/sshd_config.d/00-custom-ssh.conf` | `../sshd_00-custom-ssh.conf` |
| nftables Firewall | `/etc/sysconfig/nftables.conf` | `../nftables.conf` via `../apply_hardening.sh` |
| Fail2ban Jail | `/etc/fail2ban/jail.local` | `../fail2ban_jail.local` |
| sysctl Kernel Hardening | `/etc/sysctl.d/90-no-ping.conf` | `../sysctl_90-no-ping.conf` |
| Root Shell Parity | `/root/.*` | `../root_shell.sh` |
