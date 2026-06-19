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

1. **SSH target** — reuse a host already in `~/.ssh/config` (pick by number → prefilled via `ssh -G` → confirm; an unknown pick or a host with no user → *no match* → abort or type it by hand), or enter a new IP / user / port (blank = `22`) / alias. A new target's `~/.ssh/config` entry is written for you; if the alias you pick already exists, it asks whether to **overwrite** it (reusing an existing host leaves its entry untouched).
2. **scp protocol** — legacy `-O` (default, most compatible) or modern SFTP. Legacy avoids `subsystem request failed on channel 0` on boxes whose `sshd` lacks the SFTP subsystem (e.g. right after an OpenSSH upgrade mid-deploy).
3. **Keys** — lists the public keys in `~/.ssh/id_ed25519.pub` with your own pre-selected. Type a number to toggle it, `a`/`r` + numbers to force add/remove, Enter to confirm. Your `.pub` is never modified, and keys already on the target are skipped. **Then**, if a gitignored **`extra_keys.pub`** (repo root) holds more public keys (e.g. teammates'), it offers to copy some or all of those too, with the same picker — all selected keys go to the target in one shot.
4. **Local Python deps** (`y/N`) — optionally `pip install` the aggregated root `requirements.txt` on **this** machine (your operator PC, where the xfarm exploits run — *never* the vulnbox). Skip it if your attack box is already set up.
5. **Neovim** (`y/N`) — install Neovim (only if missing/outdated) and drop `nvimconfig.lua` at `~/.config/nvim/init.lua`.
6. **Git aliases** (`y/N`) — copy `gitconfig.conf` to the target's `~/.gitconfig_vulnbox` and link it via `include.path`.
7. **TLS bridge** (`y/N`, default no) — copy the whole `python_exploits/tls` folder to `~/tls_bridge` on the target (the bridge is meant to run ON the vulnbox). Nothing is installed — its runtime is stdlib-only; configure and start it on the box with `cd ~/tls_bridge && ./auto_tls.sh && python3 tls.py` (add `-d` to keep it running after you close the terminal — see the bridge's README).
8. **Dev checkout** (`y/N`, default no) — once setup finishes, clone this toolkit's own `dev` branch onto the target into `~/<repo>` (repo name taken from your `origin`, e.g. `~/Vulnbox-autoconfig`). The clone URL is derived from `origin` and rewritten to HTTPS so the box needs no GitHub key; an existing checkout is updated (`fetch` / `checkout` / `pull --ff-only`), never clobbered.
9. **Backup** (`y/N`) — lists the target's home, then asks which folder(s) to zip: a name under home (`Immagini`), a `~` path (`~/Immagini`), or an absolute path (`/var/www`); a trailing slash is fine and blank = whole home. Your picks are echoed as resolved paths (`~/Immagini/`) to confirm or re-enter. Finally pick where to save it locally (default `$HOME`); it's pulled as `backup_from_<IP>.zip`, with `_1`, `_2`, … appended so an existing file is never overwritten.

> Steps **4–9** are driven by the shared **`deployconf.sh`** (sourced by every distro's deploy script right after the SSH setup), so all three distros prompt identically — only the package install itself is per-distro.

> The remote setup runs `sudo` **on the target** — any password it asks for is the **vulnbox's**, not your local machine's. The script says so on screen.

## What it installs

Installs (via `apt`) zsh, Oh-My-Zsh, sets zsh as the login shell, and applies `zshconfig_debian_ubuntu.conf` as `~/.zshrc`. Core packages — including **`php`** (runtime for the PHP-based web exploits) and `zsh-syntax-highlighting` + `zsh-autosuggestions` so typed commands are colorized — plus the cosmetic extras `fastfetch lsd tty-clock cmatrix` (best-effort: a missing one is skipped, never fatal). Then drops you into a live session; reconnect any time with `ssh <alias>`.

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
| Deploy prompts (local deps, nvim/git/tls/dev, backup) | root `deployconf.sh` (shared) |
| Selection prompts (keys, git items) | root `selectlib.sh` (shared) |

Config is decoupled from deploy logic — the next run simply re-pushes your edits.

## Critical rules

- **Local only:** run from your local PC; the script warns if it detects a container.
- **Remote sudo password** = the vulnbox's, not your local machine's.
- **Right config for the distro:** don't deploy Debian/Ubuntu configs to an Arch/Fedora box.
- **Make scripts executable** after moving them: `chmod +x *.sh`.
- **Package availability:** `fastfetch`, `lsd`, and `tty-clock` aren't in every `apt` release. The deploy installs the cosmetic extras **best-effort** (one at a time) and skips any that aren't found — the rest of the setup still completes. Add a PPA or install them manually if your release lacks the ones you want. (`neofetch` was dropped — discontinued upstream; the shell runs `fastfetch` instead.)
