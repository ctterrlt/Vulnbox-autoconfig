# 🐘 Debian/Ubuntu Vulnbox AutoConfig

Automated deploy of zsh + CTF tooling to a **Debian/Ubuntu** target over SSH.
**Run from your local PC — never on the target.**

## Deploy

**Master (recommended)** — from the repo root:

```bash
./auto.sh        # then pick "Debian/Ubuntu"
```

`auto.sh` first offers to import the shared git aliases into *your* `~/.gitconfig`, then hands off to this distro's script.

**Direct** — bypass the master menu (and the operator git-import step):

```bash
cd debian_ubuntu && ./debian_ubuntu_auto.sh
```

Set `SKIP_SSH=1` to skip key generation/copy when your key is already on the box (the remaining prompts still run — they're needed downstream).

## What it asks, in order

1. **SSH target** — reuse a host already in `~/.ssh/config` (pick by number → prefilled via `ssh -G` → confirm; an unknown pick or a host with no user → *no match* → abort or type it by hand), or enter a new IP / user / port (blank = `22`) / alias. The `~/.ssh/config` entry is written once and never overwritten.
2. **scp protocol** — legacy `-O` (default, most compatible) or modern SFTP. Legacy avoids `subsystem request failed on channel 0` on boxes whose `sshd` lacks the SFTP subsystem (e.g. right after an OpenSSH upgrade mid-deploy).
3. **Keys** — lists the public keys in `~/.ssh/id_ed25519.pub` with your own pre-selected. Type a number to toggle it, `a`/`r` + numbers to force add/remove, Enter to confirm. Your `.pub` is never modified, and keys already on the target are skipped.
4. **Neovim** (`y/N`) — install Neovim (only if missing/outdated) and drop `nvimconfig.lua` at `~/.config/nvim/init.lua`.
5. **Git aliases** (`y/N`) — copy `gitconfig.conf` to the target's `~/.gitconfig_vulnbox` and link it via `include.path`.
6. **Backup** (`y/N`) — lists the target's home, then asks which folder(s) to zip: a name under home (`Immagini`), a `~` path (`~/Immagini`), or an absolute path (`/var/www`); a trailing slash is fine and blank = whole home. Your picks are echoed as resolved paths (`~/Immagini/`) to confirm or re-enter. Finally pick where to save it locally (default `$HOME`); it's pulled as `backup_from_<IP>.zip`, with `_1`, `_2`, … appended so an existing file is never overwritten.

> The remote setup runs `sudo` **on the target** — any password it asks for is the **vulnbox's**, not your local machine's. The script says so on screen.

## What it installs

Installs (via `apt`) zsh, Oh-My-Zsh, sets zsh as the login shell, and applies `zshconfig_debian_ubuntu.conf` as `~/.zshrc`. Core packages plus the cosmetic extras `fastfetch lsd tty-clock cmatrix` (best-effort — a missing one is skipped, never fatal), and `zsh-syntax-highlighting` + `zsh-autosuggestions` so typed commands are colorized. Then drops you into a live session; reconnect any time with `ssh <alias>`.

## Other entry points

- **Re-push config only** (no reinstall): `./zshchangeconf_debian_ubuntu.sh` — uploads `zshconfig_debian_ubuntu.conf` and applies it to `~/.zshrc`.
- **Standalone manual install** (run ON the box you're already sitting on): `./zshinstall_debian_ubuntu.sh`.

## Maintain

| To change… | Edit… |
|---|---|
| Shell aliases / prompt / plugins | `zshconfig_debian_ubuntu.conf` |
| Packages / install logic | `debian_ubuntu_auto.sh` |
| Neovim config | root `nvimconfig.lua` (shared) |
| Git aliases | root `gitconfig.conf` (shared) |
| SSH / key / scp prompts | root `sshconf.sh` (shared) |
| Selection prompts (keys, git items) | root `selectlib.sh` (shared) |

Config is decoupled from deploy logic — the next run simply re-pushes your edits.

## Critical rules

- **Local only:** run from your local PC; the script warns if it detects a container.
- **Remote sudo password** = the vulnbox's, not your local machine's.
- **Right config for the distro:** don't deploy Debian/Ubuntu configs to an Arch/Fedora box.
- **Make scripts executable** after moving them: `chmod +x *.sh`.
- **Package availability:** `fastfetch`, `lsd`, and `tty-clock` aren't in every `apt` release. The deploy installs the cosmetic extras **best-effort** (one at a time) and skips any that aren't found — the rest of the setup still completes. Add a PPA or install them manually if your release lacks the ones you want. (`neofetch` was dropped — discontinued upstream; the shell runs `fastfetch` instead.)
