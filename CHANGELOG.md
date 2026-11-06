<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->
<!-- Purpose: Release history and version migration notes. -->

# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Bash alias configurations for Arch, Debian/Ubuntu, and Fedora, derived from the matching Zsh aliases and installed without replacing an existing regular `.bashrc`.
- Bash configuration deployment to full installs, config refreshes, standalone host installs, and the optional root parity setup.
- SPDX license identifiers across project source and configuration files, plus the package license metadata required for JSON files.
- A CI status badge, a Development section, data handling notes, and a roadmap in the root README.

### Changed
- Hardened nftables deployment now uses a dedicated table and merges its managed rules into the existing persistent config. SSH and Fail2ban templates include the active connection port alongside the default port 22222.
- Existing `.zshrc` files are backed up before the generated distro config replaces them; Bash aliases are loaded from a separate file.
- Arch provisioning now uses `pacman` and no longer bootstraps a temporary AUR build account. Optional `yay` aliases remain available in the Arch shell configs when yay is already installed.
- Removed the AUR-only `tty-clock` package from automated Arch installs; all packages requested by the Arch provisioning scripts now go through pacman.
- Preserved the operator's `uvtotal` helper in all distro Zsh and Bash configs and restored the optional Arch `yay` aliases after comparing against the live Zsh source.
- Synced the latest local shell updates into all distro Zsh and Bash templates: conditional Android SDK PATH support, safer `uvtotal` error/empty handling, and direct nftables config reloads using each distro's service config path.
- Updated `uvinst`, `uvupdate`, and `uvtotal` to resolve one `python3` executable and use it consistently for pip discovery and `uv` installs; the install helpers now accept package arguments.
- Updated `sshrc` to prefer the local `99-custom-ssh.conf` and fall back to the project's deployed `00-custom-ssh.conf`.
- Replaced the tracked personal public-key list with a comment-only `extra_keys.pub.example`; first-run seeding creates the ignored local `extra_keys.pub` file for user-managed keys.
- Centralized key-file seeding in `sshconf.sh`, so direct distro deployments and the master menu both create the local key file.
- Added SSH-port range validation and port-aware config refresh commands.
- Fixed a missing closing parenthesis that prevented the `telecc1` sample exploit from compiling.
- Corrected README and changelog claims about container guards, backup naming, SSH login behavior, firewall rules, package installation, and the generated aliases.
- Expanded CI ShellCheck coverage and made manual release workflow runs retain their built archives as workflow artifacts.

## [2.1.0] — 2026-11-06

### Added
- **Host Defense Suite**: Added four opt-in hardening configurations:
  - `sshd_00-custom-ssh.conf`: OpenSSH server drop-in disabling password login and root login, with default port 22222 and a maximum of 3 authentication tries.
  - `nftables.conf`: Dedicated stateful input table with loopback and established connections allowed, and SSH port 22222 accepted on VPN interfaces (`wt0`, `tailscale0`) and the CGNAT subnet `100.64.0.0/10`.
  - `fail2ban_jail.local`: Fail2ban jail for `sshd` on port 22222 using systemd backend with 1-hour ban time and 5 retries.
  - `sysctl_90-no-ping.conf`: Kernel sysctl hardening disabling ICMP echo replies (`net.ipv4.icmp_echo_ignore_all = 1`).
- **Interactive Hardening Deploy Prompts**: Integrated opt-in deployment for `sshd`, `nftables`, `fail2ban`, and `sysctl` directly into `deployconf.sh` and the three distro auto-deploy scripts (`arch_auto.sh`, `debian_ubuntu_auto.sh`, `fedora_auto.sh`).
- **Modern Python/uv Shell Tooling**: Added aliases `pythonn` (`uv run python`), `uvinst`, and `uvupdate` to the distro Zsh configurations.
- **Defensive Shell Shortcuts**: Added `fail2banrc`, `fail2ban`, `nftables`, `nftablesrc`, and `sshrc` aliases to inspect and modify security configurations rapidly.
- **Universal AI Agent Context**: Added `Agents.md` project blueprint and operating instructions compatible across all LLMs and coding assistants.
- **CI/CD Automation**: Added GitHub Actions workflows for shell/Python checks (`ci.yaml`) and tag-based release packaging (`release.yaml`).

### Changed
- **License Upgrade**: Upgraded project licensing to the GNU Affero General Public License v3.0 or later (`AGPL-3.0-or-later`) with SPDX identifiers across documentation.
- **Documentation Overhaul**: Completely redesigned root `README.md` and all per-directory `README.md` files with Shields.io badges, compatibility matrix, Mermaid architecture diagrams, and exploit catalogs.
- **Shell Alias Hardening**:
  - Removed unnecessary `sudo` from `nvimrc` and `nvimconf` aliases since `~/.config/nvim/init.lua` is user-owned.
  - Updated `pipinst` alias to include `--user --break-system-packages`.
  - Updated Docker log alias from `dlog` to `dlogs` (`docker compose logs -f`).
- **Gitignore Modernization**: Updated `.gitignore` to use `**/**/Agents.md` wildcard patterns matching modern agent sync conventions.

---

## [2.0.0] — 2026-07-18

### Added
- **ExploitFarm Arsenal Expansion**: Integrated full Attack/Defense exploit arsenal supporting [ExploitFarm](https://github.com/Pwnzer0tt1/exploitfarm) and `xfarm`.
- **Crypto Oracles**: Added automated exploits for AES-ECB padding oracle, RSA blinding oracle, DES brute force, bitwise OR-flag recovery, and timing side-channel attacks.
- **Web & Binary Exploits**: Added SQL injection exploration and column dump tools, weak-hash session cookie forgery with PHP `crypt()` helper, canary ret2win, and ROP to `execve`.
- **Defensive TLS Bridge**: Added asyncio TLS interception proxy (`python_exploits/tls`) for decrypting, tapping, and re-encrypting vulnbox service traffic.
- **Root Parity Orchestrator**: Added `root_shell.sh` to mirror user zsh environment, Oh-My-Zsh, dotfiles, and SSH credentials into `/root`.
- **Pwnzer0tt1 Tooling Menu**: Integrated automated cloning and updating of `exploitfarm`, `digger`, and `firegex` with branch switching (`main` vs `dev`).
- **Selective Backup & Git Init**: Added interactive remote home directory inspection (`lsd`), selective archiving, and non-destructive downloads.

---

## [1.0.0] — 2026-06-05

### Added
- **Initial Release**: Multi-distro remote provisioning suite for Arch Linux, Debian/Ubuntu, and Fedora over SSH.
- **Zsh & Oh-My-Zsh Automation**: Automated installation, default shell configuration, and plugin loading (`zsh-syntax-highlighting`, `zsh-autosuggestions`).
- **Zero-Touch SSH**: Host key generation, public key deployment, and `~/.ssh/config` entry creation.
- **Shared Editor & Terminal Configs**: Opt-in provisioning for Neovim (`nvimconfig.lua`), nano (`nanorc`), Git (`gitconfig.conf`), and Konsole (`konsolerc`).
