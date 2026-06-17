# 🐧 Arch-Based Vulnbox AutoConfig

This module handles the automated deployment of Zsh and CTF tooling on Arch Linux targets.

## 🚀 Deployment Methods

### 1. Master Deployment (Recommended)

This is the fastest way to get set up. It uses the root `auto.sh` script to handle everything across any distribution.

1. Navigate to the project root.
2. Run `./auto.sh`.
3. Select **Arch** from the menu.

### 2. Direct Deployment (Manual)

If you are already inside the `arch/` folder and want to deploy **only** to an Arch target, you can bypass the master menu.

**Prerequisites:**

1. Ensure `zshconfig_arch.conf` is configured to your liking.
2. Make the script executable: `chmod +x arch_auto.sh`

**Command:**

```bash
./arch_auto.sh
```

---

## 🔄 Re-pushing Config Only

If you only changed `zshconfig_arch.conf` and don't need a full redeployment, use:

```bash
./zshchangeconf_arch.sh
```

This uploads the config and applies it to `~/.zshrc` on the remote target without reinstalling packages.

---

## 🛠 Configuration Management

- To change aliases, themes, or plugins: edit `arch/zshconfig_arch.conf`.
- To change the Neovim config: edit the root `nvimconfig.lua` — shared across all distros. The deploy asks before applying it.
- To change install logic (e.g. adding a package): edit `arch/arch_auto.sh`.
- To change SSH setup (prompts, key gen, key copy, `~/.ssh/config`): edit the root `sshconf.sh` — shared across all distros.

Your configuration is decoupled from the deployment logic. Any changes to `zshconfig_arch.conf` are automatically pushed to the remote target on the next deployment.

---

## 🔌 Port & SSH Config

First the script offers to **reuse a host already in `~/.ssh/config`** — pick one by number to prefill its IP/user/port, or press Enter to set up a new target. An entry that matches nothing (or a host with no user defined) reports a **no match** and lets you abort or type the details by hand.

For a new target it prompts for four connection parameters:

| Prompt | Default | Notes |
|---|---|---|
| Target IP | — | Required |
| Username | — | Required |
| SSH Port | `22` | Leave blank to use the default |
| Host alias | IP address | Friendly name used in `~/.ssh/config` (e.g. `vulnbox`) |

Before copying the key it lists the public keys in `id_ed25519.pub` and asks **which one(s) to copy** (default: the key matching your private key). Your `.pub` file is left untouched, and any key already on the target is skipped.

After deployment you can reconnect with just:

```bash
ssh vulnbox
```

The `~/.ssh/config` entry is written once and never overwritten on subsequent runs.

The deploy then asks one more question — whether to push the shared Neovim config (`nvimconfig.lua`) to `~/.config/nvim/init.lua`. Answer `y` to install Neovim (only if missing or outdated) and apply it; anything else leaves the box's editor setup untouched.

If your key is already deployed, skip key-gen and key-copy with:

```bash
SKIP_SSH=1 ./arch_auto.sh
```

---

## ⚠️ Critical Rules

- **Local vs. Remote:** Always run these scripts from your **Local PC**.
- **Remote sudo password:** the box setup runs `sudo` on the **target**. When prompted for a password, enter the **vulnbox's** — not your local machine's.
- **Standardization:** Use the correct config for the target distro — do not copy Arch configs to a Debian/Fedora box.
- **Permissions:** If you move scripts to a new machine, make them executable again: `chmod +x *.sh`
