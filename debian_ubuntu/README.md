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

The script prompts for four connection parameters:

| Prompt | Default | Notes |
|---|---|---|
| Target IP | — | Required |
| Username | — | Required |
| SSH Port | `22` | Leave blank to use the default |
| Host alias | IP address | Friendly name used in `~/.ssh/config` (e.g. `vulnbox`) |

After deployment you can reconnect with just:

```bash
ssh vulnbox
```

The `~/.ssh/config` entry is written once and never overwritten on subsequent runs.

The deploy then asks one more question — whether to push the shared Neovim config (`nvimconfig.lua`) to `~/.config/nvim/init.lua`. Answer `y` to install Neovim (only if missing or outdated) and apply it; anything else leaves the box's editor setup untouched.

If your key is already deployed, skip key-gen and key-copy with:

```bash
SKIP_SSH=1 ./debian_ubuntu_auto.sh
```

---

## ⚠️ Critical Rules

- **Local vs. Remote:** Always run these scripts from your **Local PC**.
- **Standardization:** Use the correct config for the target distro — do not copy Debian/Ubuntu configs to an Arch or Fedora box.
- **Permissions:** If you move scripts to a new machine, make them executable again: `chmod +x *.sh`
- **Package availability:** `fastfetch`, `lsd`, and `tty-clock` are not in the default `apt` repos. If the install fails, add their PPAs or install them manually before running the script.
