# 🐧 Arch Vulnbox AutoConfig

Automated deploy of zsh + CTF tooling to an **Arch Linux** target over SSH.
**Run from your local PC — never on the target.**

## Deploy

**Master (recommended)** — from the repo root:

```bash
./auto.sh        # then pick "Arch"
```

`auto.sh` first offers to import the shared git aliases into *your* `~/.gitconfig`, then hands off to this distro's script.

**Direct** — bypass the master menu (and the operator git-import step):

```bash
cd arch && ./arch_auto.sh
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
8. **nano config** (`y/N`, default no) — drop the shared `nanorc` to the target's `~/.nanorc` (per-user — no root, read after `/etc/nanorc` so it overrides without clobbering it): line numbers, syntax highlight, sane defaults.
9. **Konsole config** (`y/N`, default no) — drop `konsolerc` → `~/.config/konsolerc` and the profile → `~/.local/share/konsole/Vulnbox.profile`. Konsole isn't installed (vulnboxes are usually headless) — the files are harmless if absent, ready if it's present. The konsolerc shortcuts are a static baseline; the deployed `.zshrc` also **live-syncs** Konsole's `[Shortcuts]` from an `Action=Key` text file you maintain (`~/Documents/konsole/shortcuts.txt`, `~/Documenti/…`, or `KONSOLE_SHORTCUTS=`), re-applying it on the next shell whenever it changes.
10. **Target root shell** (`Y/n`, **default yes**) — also give the box's **root** this zsh setup (ships `root_shell.sh`, run by the payload as `sudo bash root_shell.sh $USER`): chsh root → zsh, Oh-My-Zsh for root, your `~/.zshrc`/`.nanorc`/`.gitconfig`/`nvim` symlinked into `/root` and your `~/.ssh` config+keys copied there, so `sudo su` / `su -` on the box keep your shell *and* nano/ssh/git config instead of a bare bash. Skipped automatically if you deploy *as* root. You're never left in a root shell — the deploy still logs you in as your normal user at the end.
11. **Dev checkout** (`y/N`, default no) — once setup finishes, clone this toolkit's own `dev` branch onto the target into `~/<repo>` (repo name taken from your `origin`, e.g. `~/Vulnbox-autoconfig`). The clone URL is derived from `origin` and rewritten to HTTPS so the box needs no GitHub key; an existing checkout's **remote origin is updated** if the protocol differs from the deployed URL, then it does `fetch` / `checkout` / `pull --ff-only`.
12. **Backup** (`y/N`) — lists the target's home, then asks which folder(s) to zip: a name under home (`Immagini`), a `~` path (`~/Immagini`), or an absolute path (`/var/www`); a trailing slash is fine and blank = whole home. Your picks are echoed as resolved paths (`~/Immagini/`) to confirm or re-enter. Finally pick where to save it locally (default `$HOME`); it's pulled as `backup_from_<IP>.zip`, with `_1`, `_2`, … appended so an existing file is never overwritten.

> Steps **4–12** are driven by the shared **`deployconf.sh`** (sourced by every distro's deploy script right after the SSH setup), so all three distros prompt identically — only the package install itself is per-distro.

> The remote setup runs `sudo` **on the target** — any password it asks for is the **vulnbox's**, not your local machine's. The script says so on screen.

## What it installs

Installs (via `yay`, bootstrapping it if absent) zsh, Oh-My-Zsh, sets zsh as the login shell, and applies `zshconfig_arch.conf` as `~/.zshrc`. Core packages — including **`php`** (runtime for the PHP-based web exploits) and `zsh-syntax-highlighting` + `zsh-autosuggestions` so typed commands are colorized — plus the cosmetic extras `fastfetch lsd tty-clock cmatrix` (best-effort: a missing one is skipped, never fatal). The deployed `.zshrc` also prepends the sbin dirs (`/usr/local/sbin /usr/sbin /sbin`) to `PATH` when missing, so admin tools (`ip`, `ss`, `iptables`, `fdisk`, …) resolve on minimal distros — e.g. **antiX** — that leave sbin off a normal user's PATH. After the deploy it prints a **deployment summary** (SSH fingerprint, features deployed, checklist) and drops you into a live session (explicitly sourcing `~/.zshrc` first so all changes are active); reconnect any time with `ssh <alias>`.

## Other entry points

- **Re-push config only** (no reinstall): `./zshchangeconf_arch.sh` — uploads `zshconfig_arch.conf` and applies it to `~/.zshrc`.
- **Standalone manual install** (run ON the box you're already sitting on): `./zshinstall_arch.sh`.

## Maintain

| To change… | Edit… |
|---|---|
| Shell aliases / prompt / plugins | `zshconfig_arch.conf` |
| Packages / install logic | `arch_auto.sh` |
| Neovim config | root `nvimconfig.lua` (shared) |
| Git aliases | root `gitconfig.conf` (shared) |
| nano config (`~/.nanorc`) | root `nanorc` (shared) |
| Konsole config (`~/.config/konsolerc` + profile) | root `konsolerc` / `konsole.profile` (shared) |
| sbin on PATH / shell behaviour | `zshconfig_arch.conf` |
| SSH / key / scp prompts | root `sshconf.sh` (shared) |
| Deploy prompts (local deps, nvim/git/tls/nano/konsole/rootshell/dev, backup) | root `deployconf.sh` (shared) |
| Target root shell (make the box's root use zsh) | root `root_shell.sh` (shipped + run by the payload) |
| Selection prompts (keys, git items) | root `selectlib.sh` (shared) |

Config is decoupled from deploy logic — the next run simply re-pushes your edits.

## Critical rules

- **Local only:** run from your local PC; the script warns if it detects a container.
- **Remote sudo password** = the vulnbox's, not your local machine's.
- **Right config for the distro:** don't deploy Arch configs to a Debian/Fedora box.
- **Make scripts executable** after moving them: `chmod +x *.sh`.
- **Packages:** both the deploy and `zshinstall_arch.sh` bootstrap `yay` automatically if it's missing (handles root and non-root). Cosmetic extras install one-at-a-time best-effort, so one unavailable package can't abort the run.
