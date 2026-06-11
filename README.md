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
    ├── crypto/                          # crypto & brute-force oracles (6 projects)
    ├── binary/                          # pwn / memory-corruption (2 projects)
    ├── web/sql/                         # boolean-blind SQL-injection toolkit (3 tools)
    ├── converting/                      # offline encoding/decoding helpers
    ├── tls/                             # defensive TLS decrypt→tap→re-encrypt bridge (runs ON the vulnbox)
    └── examples/                        # reference templates + raw jeopardy_examples/
```

Every project folder is self-contained: `<project>.py` (exploit) ·
`module_<project>.py` (config) · `auto_<project>.sh` (interactive setup) ·
`requirements.txt` · a generated `.env` · and a `README.md`. The one exception is
`tls/`, which is a long-running defensive proxy daemon rather than an xfarm
exploit — it keeps the same config layout but runs on the vulnbox (see below).

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

Each exploit reads every target-specific value (host port, prompts, addresses,
alphabets, injection style…) from a small config module — editable by hand or
through an interactive `auto_*.sh` — so the same code retargets to any team's
service in seconds. Start with
[`python_exploits/README.md`](python_exploits/README.md) for the ExploitFarm
server setup and the shared project pattern.

| Category | Projects |
|---|---|
| [`crypto/`](python_exploits/crypto) | AES-ECB oracle · RSA blinding oracle · DES login brute · OR-flag rebuild · score oracle · timing attack |
| [`binary/`](python_exploits/binary) | canary leak → ret2win · ROP → `execve` (32/64-bit) |
| [`web/sql/`](python_exploits/web/sql) | boolean-blind SQLi: explore schema · dump column · both — configurable injection style + on-the-wire encoding (`plain`/`url`/`hex`/`base64`/`double_url`) to beat naive WAF/regex |
| [`converting/`](python_exploits/converting) | offline url/hex/base64 helpers for crafting firewall regex |
| [`tls/`](python_exploits/tls) | **defensive** TLS decrypt → plaintext tap → re-encrypt bridge — read your own service's encrypted traffic (runs on the vulnbox, not an exploit) |

---

## ⚠️ Safety & where things run

Three different places — don't mix them up:

- **Deploy scripts (`auto.sh`, `sshconf.sh`, distro folders):** run from **your local
  PC**, never on the target. They refuse to run inside a container or from the wrong
  directory — heed the **DANGER** prompts if they appear.
- **Exploit arsenal (xfarm projects):** run on the **machine hosting ExploitFarm —
  your operator PC or attack server, _not_ the vulnbox**. xfarm fans every exploit
  out across all teams each tick; that load on a vulnbox is heavy enough that you'd
  effectively DoS your own box, on top of leaking your attacks to whoever owns it.
- **`tls/` bridge:** the one piece that **runs on the vulnbox**. It sits in front of
  one of your own services, terminates its TLS locally, and exposes the plaintext so
  you can inspect it — so it has to live where the service does.

---

## 🙏 Credits

[**ExploitFarm**](https://github.com/Pwnzer0tt1/exploitfarm) and **xfarm**, by
[**Pwnzer0tt1**](https://github.com/Pwnzer0tt1) — the engine the entire exploits are built for.

Happy hacking! 🛡✨

