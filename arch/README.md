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
- To change install logic (e.g. adding a package): edit `arch/arch_auto.sh`.

Your configuration is decoupled from the deployment logic. Any changes to `zshconfig_arch.conf` are automatically pushed to the remote target on the next deployment.

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

---

## ⚠️ Critical Rules

- **Local vs. Remote:** Always run these scripts from your **Local PC**.
- **Standardization:** Use the correct config for the target distro — do not copy Arch configs to a Debian/Fedora box.
- **Permissions:** If you move scripts to a new machine, make them executable again: `chmod +x *.sh`
