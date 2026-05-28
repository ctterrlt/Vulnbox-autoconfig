# 🎯 Fedora-Based Vulnbox AutoConfig

This toolkit streamlines the setup of Fedora-based CTF Vulnboxes. Choose your deployment strategy based on whether you want a full-auto blast or specific control over the configuration.

## 🚀 Deployment Methods

### 1. Automatic Deployment (The All-in-One)
Best for rapid deployment when you want to handle everything from your local machine. This will push keys, install packages, apply configs, and drop you into a fresh Zsh session.

* **Where to run:** Your Local PC.
* **Prerequisite (Set permissions):**
    ```bash
    chmod +x *.sh
    ```
* **Command:**
    ```bash
    ./fedora_auto.sh
    ```

---

### 2. Manual Deployment (The Granular Way)
Use this if you prefer to build the environment step-by-step or need to customize the installation on the fly. 

To keep it simple, we use the `s` and `b` naming convention:
* **`s` (Server / SSH Machine):** These are the scripts you execute **on the remote Vulnbox**.
* **`b` (Base / Local Machine):** These are the scripts you run **on your local computer**.

#### Workflow:
1.  **On the Vulnbox (`s`):**
    * Make executable: `chmod +x zshinstall_fedora.sh zshchangeconf_fedora.sh`
    * Execute `zshinstall_fedora.sh` to get the base environment and Zsh.
    * Execute `zshchangeconf_fedora.sh` to apply the specific config.

2.  **On your Own PC (`b`):**
    * Make executable: `chmod +x sshconf.sh`
    * Execute `sshconf.sh` to generate keys and handle the deployment to the target.

---

## ⚠️ Critical Rule
* **Always check your context:** Running a script labeled for `s` on your local machine might unintentionally change your local shell or overwrite your personal config. 
* **Targeting:** Ensure you are targeting the Vulnbox's distribution. If the target is not Fedora-based, do not use these scripts; check the `arch` or `debian_ubuntu` folders instead.
