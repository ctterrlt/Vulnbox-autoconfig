# 🐘 Debian/Ubuntu-Based Vulnbox AutoConfig

This module handles the automated deployment of Zsh and CTF tooling on Debian/Ubuntu targets.

## 🚀 Deployment Methods

### 1. Master Deployment (Recommended)

This is the fastest way to get set up. It uses the root `auto.sh` script to handle everything across any distribution.

1. Navigate to the project root.
2. Run `./auto.sh`.
3. Select **Debian/Ubuntu** from the menu.

### 2. Direct Deployment (Manual)

If you are already inside the `debian_ubuntu/` folder and want to deploy **only** to a Debian/Ubuntu target, you can bypass the master menu.

**Prerequisites:**

1. Ensure `zshconfig_debian_ubuntu.conf` is configured to your liking.
2. Make the script executable: `chmod +x debian_ubuntu_auto.sh`

**Command:**

```bash
./debian_ubuntu_auto.sh
```

---

## 🔄 Re-pushing Config Only

If you only changed `zshconfig_debian_ubuntu.conf` and don't need a full redeployment, use:

```bash
./zshchangeconf_debian_ubuntu.sh
```

This uploads the config and applies it to `~/.zshrc` on the remote target without reinstalling packages.

---

## 🛠 Configuration Management

- To change aliases, themes, or plugins: edit `debian_ubuntu/zshconfig_debian_ubuntu.conf`.
- To change the Neovim config: edit the root `nvimconfig.lua` — shared across all distros. The deploy asks before applying it.
- To change install logic (e.g. adding a package): edit `debian_ubuntu/debian_ubuntu_auto.sh`.
- To change SSH setup (prompts, key gen, key copy, `~/.ssh/config`): edit the root `sshconf.sh` — shared across all distros.

Your configuration is decoupled from the deployment logic. Any changes to `zshconfig_debian_ubuntu.conf` are automatically pushed to the remote target on the next deployment.

---

## 🔌 Port & SSH Config

First the script offers to **reuse a host already in `~/.ssh/config`** — pick one by number to prefill its IP/user/port (then confirm it), or press Enter to set up a new target. An entry that matches nothing (or a host with no user defined) reports a **no match** and lets you abort or type the details by hand.

For a new target it prompts for four connection parameters:

| Prompt | Default | Notes |
|---|---|---|
| Target IP | — | Required |
| Username | — | Required |
| SSH Port | `22` | Leave blank to use the default |
| Host alias | IP address | Friendly name used in `~/.ssh/config` (e.g. `vulnbox`) |

Before copying the key it lists the public keys in `id_ed25519.pub` with your own key pre-selected, and lets you **confirm / add / remove** which one(s) to copy (type a number to toggle it, `a`/`r` + numbers to force add/remove, Enter to confirm). Your `.pub` file is left untouched, and any key already on the target is skipped.

It then asks whether to use the **legacy scp protocol (`-O`)** — the default and most compatible. Modern `scp` uses the SFTP subsystem, which can fail with `subsystem request failed on channel 0` on boxes whose `sshd` lacks it (e.g. right after an OpenSSH upgrade mid-deploy); answer `n` only if you specifically want SFTP.

After deployment you can reconnect with just:

```bash
ssh vulnbox
```

The `~/.ssh/config` entry is written once and never overwritten on subsequent runs.

The deploy then asks whether to push the shared Neovim config (`nvimconfig.lua`) to `~/.config/nvim/init.lua`. Answer `y` to install Neovim (only if missing or outdated) and apply it; anything else leaves the box's editor setup untouched.

It also asks whether to deploy the shared **git aliases** (`gitconfig.conf`) to the target's `~/.gitconfig`. On `y` the payload drops them in `~/.gitconfig_vulnbox` and links that via `include.path`; on `N` the target's git config is left alone.

Finally it asks whether to **pull a backup** before finishing (`y/N`). On `y` it lists the target's home so you can see what's there, then asks which folder(s) to zip — space-separated, each one a name under home (`Immagini`), a `~` path (`~/Immagini`), or an absolute path (`/var/www`); a trailing slash is fine and blank means the whole home dir. It echoes your selection as the resolved path (e.g. `~/Immagini/`) to confirm (or re-enter), then asks where to save the archive locally (default your home dir) and pulls it there as `backup_from_<IP>.zip`. On `N` nothing is zipped or pulled.

If your key is already deployed, skip key-gen and key-copy with:

```bash
SKIP_SSH=1 ./debian_ubuntu_auto.sh
```

---

## ⚠️ Critical Rules

- **Local vs. Remote:** Always run these scripts from your **Local PC**.
- **Remote sudo password:** the box setup runs `sudo` on the **target**. When prompted for a password, enter the **vulnbox's** — not your local machine's.
- **Standardization:** Use the correct config for the target distro — do not copy Debian/Ubuntu configs to an Arch or Fedora box.
- **Permissions:** If you move scripts to a new machine, make them executable again: `chmod +x *.sh`
- **Package availability:** `fastfetch`, `lsd`, and `tty-clock` aren't in every `apt` release. The deploy installs the cosmetic extras **best-effort** (one at a time) and simply skips any that aren't found — the rest of the setup still completes. Add a PPA or install them manually if your release lacks the ones you want. (`neofetch` was dropped — it's discontinued upstream; the shell runs `fastfetch` instead.)
