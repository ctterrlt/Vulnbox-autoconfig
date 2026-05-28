k# 🐘 Debian/Ubuntu-Based Vulnbox AutoConfig

This module handles the automated deployment of Zsh and CTF tooling on Debian/Ubuntu targets. 

## 🚀 Deployment Methods

### 1. Master Deployment (Recommended)
This is the fastest way to get set up. It uses the root `auto_deploy.sh` script to handle everything across any distribution.

1. Navigate to the project root.
2. Run `./auto_deploy.sh`.
3. Select "Debian/Ubuntu" from the menu.

### 2. Direct Deployment (Manual)
If you are already inside the `debian_ubuntu/` folder and want to deploy **only** to a Debian/Ubuntu target, you can bypass the master menu.

**Prerequisites:**
1. Ensure your `zsh.conf` is configured to your liking.
2. Run `chmod +x debian_ubuntu_auto.sh`.

**Command:**
```bash
./debian_ubuntu_auto.sh

🛠 Configuration Management

We have moved away from hardcoded scripts. To customize your environment:

    To change aliases, themes, or plugins: Simply edit debian_ubuntu/zsh.conf.

    To change the install logic (e.g., adding a new package): Edit debian_ubuntu/debian_ubuntu_auto.sh.

Your configuration is now decoupled from the deployment logic. Any changes made to zsh.conf are automatically pushed to the remote target during your next deployment.
⚠️ Critical Rules

    Local vs. Remote: Always run these scripts from your Local PC.

    Standardization: Ensure you are using the correct zsh.conf for the target distro (e.g., do not copy Arch configs to a Debian box).

    Permissions: Always check that scripts are executable (chmod +x *.sh) if you move them to a new machine.
