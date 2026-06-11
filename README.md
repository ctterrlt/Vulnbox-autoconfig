# 🚀 Vulnbox-AutoConfig

A toolkit for **Attack/Defense CTFs**, built around the two things you always need
to do fast under pressure:

1. **🛠 Vulnbox setup** — turn a fresh remote shell into a fully configured
   operator environment (zsh, Oh-My-Zsh, aliases, offensive tooling) with a single
   command, over SSH.
2. **💉 Exploit arsenal** — drop-in, service-agnostic exploits that plug straight
   into [**ExploitFarm**](https://github.com/Pwnzer0tt1/exploitfarm) and fire at
   every team, every tick.

---

## 📂 Repository structure

```text
.
├── auto.sh                          # entry point — pick a distro and deploy
├── sshconf.sh                       # shared SSH setup (prompts, ~/.ssh/config, keys)
├── gitconfig.conf                   # shared git aliases
│
├── arch/  ·  debian_ubuntu/  ·  fedora/      # one folder per distribution
│   ├── <distro>_auto.sh                 # full deploy
│   ├── zshchangeconf_<distro>.sh        # re-push the config only
│   ├── zshconfig_<distro>.conf          # the .zshrc that gets deployed
│   ├── zshinstall_<distro>.sh           # standalone manual installer
│   └── README.md
│
└── python_exploits/                 # the exploit arsenal (ExploitFarm / xfarm)
    ├── examples/                        # reference templates for the xfarm skeleton
    └── sql/                             # service-agnostic SQL-injection exploits
        ├── explore_database/                # leak the schema
        ├── dump_column/                     # leak a column's values
        └── explore_and_dump/                # both, in one run
```

---

## 🛠 Part 1 — Vulnbox setup

### Highlights

- **One command:** `./auto.sh` handles any supported distro from a single menu.
- **Zero-touch SSH:** generates a key, copies it to the target, and writes a
  `~/.ssh/config` entry so you can reconnect later with just `ssh <alias>`.
- **One source of truth:** every distro shares the same `zshconfig` and git setup.
- **CTF-ready shell:** aliases for Docker, networking and VPNs, plus Fastfetch,
  Oh-My-Zsh, syntax highlighting and autosuggestions.
- **Automatic backup:** zips the remote home directory and pulls it down locally.

### Deploy

```bash
chmod +x auto.sh
./auto.sh
```

Pick the target distribution, then enter the IP, username, SSH port (blank = 22)
and an optional alias. The script writes the `~/.ssh/config` entry, sets up the
key, installs zsh and tooling on the box, applies the config, pulls a backup, and
drops you into a live session.

> Already have your key on the target? Skip key generation and copy with
> `SKIP_SSH=1 ./auto.sh` — the connection prompts still run, they're needed for the
> rest of the deploy.

### Maintain

| To change… | Edit… |
|---|---|
| Shell aliases, themes, plugins | `<distro>/zshconfig_<distro>.conf` |
| Git aliases | `gitconfig.conf` |
| SSH setup (keys, `~/.ssh/config`) | `sshconf.sh` (shared by all distros) |

Configuration is decoupled from deploy logic, so the next `./auto.sh` simply
re-pushes your edits. Per-distro details live in each distribution's README.

---

## 💉 Part 2 — Exploit arsenal

Every exploit here runs on [**ExploitFarm**](https://github.com/Pwnzer0tt1/exploitfarm)
and its `xfarm` client by [**Pwnzer0tt1**](https://github.com/Pwnzer0tt1), which
handle target dispatching, flag extraction and submission. The exploits focus only
on the attack: they share a fixed skeleton (`get_host()`, `Store()`, `get_ids()`,
the per-tick loop), so xfarm can replicate them across every team automatically and
the target IP is injected at runtime — never hardcoded.

Start with [`python_exploits/README.md`](python_exploits/README.md) for the
ExploitFarm server setup and the exploit structure.

### SQL injection — [`python_exploits/sql/`](python_exploits/sql/)

A boolean-blind SQL-injection toolkit that retargets to **any** service in seconds.
All target-specific details — endpoint, parameter, oracle marker, injection style,
encoding — live in a small config module, editable by hand or through an
interactive setup script.

| Tool | What it does |
|---|---|
| [`explore_database/`](python_exploits/sql/explore_database) | Leak the schema: database, tables, columns |
| [`dump_column/`](python_exploits/sql/dump_column) | Leak every value of a chosen column |
| [`explore_and_dump/`](python_exploits/sql/explore_and_dump) | Both, in a single run |

Choose the **injection style** (`or`, `and`, `or_like`, `union`, … or a fully
custom payload) and the **on-the-wire encoding** (`plain`, `url`, `hex`, `base64`,
`double_url`) to slip past naive WAF/regex filters. Full reference in
[`python_exploits/sql/README.md`](python_exploits/sql/README.md).

---

## ⚠️ Safety

- **Run everything from your local PC**, never on the target vulnbox.
- Deploy scripts refuse to run inside a container or from the wrong directory —
  heed the **DANGER** prompts if they appear.

---

## 🙏 Credits

[**ExploitFarm**](https://github.com/Pwnzer0tt1/exploitfarm) and **xfarm**, by
[**Pwnzer0tt1**](https://github.com/Pwnzer0tt1) — the engine the entire exploits are built for.

Happy hacking! 🛡✨

