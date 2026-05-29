# 👒 Fedora-Based Vulnbox AutoConfig

This module handles the automated deployment of Zsh and CTF tooling on Fedora/RHEL-based targets.

## 🚀 Deployment Methods

### 1. Master Deployment (Recommended)

This is the fastest way to get set up. It uses the root `auto.sh` script to handle everything across any distribution.

1. Navigate to the project root.
2. Run `./auto.sh`.
3. Select **Fedora** from the menu.

### 2. Direct Deployment (Manual)

If you are already inside the `fedora/` folder and want to deploy **only** to a Fedora target, you can bypass the master menu.

**Prerequisites:**

1. Ensure `zshconfig_fedora.conf` is configured to your liking.
2. Make the script executable: `chmod +x fedora_auto.sh`

**Command:**

```bash
./fedora_auto.sh
```

---

## 🔄 Re-pushing Config Only

If you only changed `zshconfig_fedora.conf` and don't need a full redeployment, use:

```bash
./zshchangeconf_fedora.sh
```

This uploads the config and applies it to `~/.zshrc` on the remote target without reinstalling packages.

---

## 🛠 Configuration Management

- To change aliases, themes, or plugins: edit `fedora/zshconfig_fedora.conf`.
- To change install logic (e.g. adding a package): edit `fedora/fedora_auto.sh`.

Your configuration is decoupled from the deployment logic. Any changes to `zshconfig_fedora.conf` are automatically pushed to the remote target on the next deployment.

---

## ⚠️ Critical Rules

- **Local vs. Remote:** Always run these scripts from your **Local PC**.
- **Standardization:** Use the correct config for the target distro — do not copy Fedora configs to an Arch or Debian/Ubuntu box.
- **Permissions:** If you move scripts to a new machine, make them executable again: `chmod +x *.sh`
- **Package availability:** `fastfetch`, `lsd`, and `tty-clock` may not be in the default Fedora repos. If the install fails, enable RPM Fusion or install them manually before running the script.
