#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Install a distro's Bash aliases without replacing the user's existing .bashrc.
set -euo pipefail

config_path="${1:-}"
if [[ -z "$config_path" || ! -f "$config_path" ]]; then
    echo "Usage: $0 /path/to/bashconfig_<distro>.conf" >&2
    exit 2
fi

install -m 644 "$config_path" "$HOME/.bashrc_vulnbox"

if [[ -L "$HOME/.bashrc" ]]; then
    echo "Installed ~/.bashrc_vulnbox. ~/.bashrc is a symlink; source it there to enable these aliases."
    exit 0
fi

touch "$HOME/.bashrc"
start_marker="# >>> Vulnbox-AutoConfig Bash aliases >>>"
if ! grep -Fq "$start_marker" "$HOME/.bashrc"; then
    bashrc_tmp=$(mktemp "$HOME/.bashrc.XXXXXX")
    {
        # This expression is written literally so the target shell expands it when sourcing .bashrc.
        # shellcheck disable=SC2016
        printf '%s\n' \
            "$start_marker" \
            '[ -r "$HOME/.bashrc_vulnbox" ] && . "$HOME/.bashrc_vulnbox"' \
            '# <<< Vulnbox-AutoConfig Bash aliases <<<'
        cat "$HOME/.bashrc"
    } > "$bashrc_tmp"
    chmod --reference="$HOME/.bashrc" "$bashrc_tmp"
    mv "$bashrc_tmp" "$HOME/.bashrc"
fi

echo "Bash aliases installed in ~/.bashrc_vulnbox and enabled by ~/.bashrc."
