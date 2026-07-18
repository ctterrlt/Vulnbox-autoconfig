#!/bin/bash
# Shared selection helpers — sourced by auto.sh and sshconf.sh.
# Gives every "pick from a list" prompt the same review step: show what's
# currently selected, then confirm / add / remove before continuing.

# Include guard (harmless if sourced more than once).
[[ -n "${_SELECTLIB_LOADED:-}" ]] && return 0 2>/dev/null
_SELECTLIB_LOADED=1

# _sl_has ARRAYNAME VALUE  -> 0 if VALUE is already in the array, else 1.
_sl_has() {
    local -n __h_arr="$1"
    local want="$2" x
    for x in "${__h_arr[@]:-}"; do
        [[ "$x" == "$want" ]] && return 0
    done
    return 1
}

# review_selection OPTIONS_ARRAY SELECTED_ARRAY [label]
#   OPTIONS_ARRAY  : all choices as display strings (0-based).
#   SELECTED_ARRAY : 1-based indices into OPTIONS — seeded with the default
#                    selection and edited in place; holds the final pick on return.
#   label          : noun shown in the prompts (default "item").
# Each round lists the current selection + all options, then reads a line:
#   - Enter (or 'c')      -> confirm and return
#   - any number(s)       -> TOGGLE those items (in if out, out if in)
#   - 'a <nums>'          -> force-add those items
#   - 'r <nums>'          -> force-remove those items
# Numbers are pulled from anywhere in the line, so stray brackets/commas/words
# (e.g. "a <1 2>", "1,2", "add 2") all work.
review_selection() {
    local -n __r_opts="$1"
    local -n __r_sel="$2"
    local label="${3:-item}"
    local _line _first _mode n x
    local -a _nums kept

    while true; do
        echo
        echo "Selected ${label}(s):"
        if (( ${#__r_sel[@]} == 0 )); then
            echo "    (none)"
        else
            for n in "${__r_sel[@]}"; do
                printf "    %s) %s\n" "$n" "${__r_opts[$((n - 1))]}"
            done
        fi
        echo "All ${label}s:"
        for n in "${!__r_opts[@]}"; do
            printf "    %s) %s\n" "$((n + 1))" "${__r_opts[$n]}"
        done
        echo "Examples:  '2' → toggle · '1 2' → toggle both · 'a 2' → add · 'r 2' → remove"
        echo "          'all' → toggle all · 'a all' → add all · 'r all' → remove all · Enter → confirm"
        read -rp "Your choice: " _line

        # Detect the "all" keyword (last word) regardless of prefix.
        _last_word="$(printf '%s' "$_line" | grep -oE '[[:alpha:]]+$' | tr '[:upper:]' '[:lower:]' || true)"
        _all_req=0
        [[ "$_last_word" == "all" ]] && _all_req=1

        # First non-space char selects the mode; numbers come from the whole line.
        _first="$(printf '%s' "$_line" | sed -E 's/^[[:space:]]*//' | cut -c1)"
        mapfile -t _nums < <(printf '%s' "$_line" | grep -oE '[0-9]+')

        case "$_first" in
            ""|c|C) return 0 ;;
            a|A)      _mode=add ;;
            r|R)      _mode=remove ;;
            *)        _mode=toggle ;;
        esac

        # "all" overrides per-number processing.
        # Mode is determined by the word BEFORE "all" (if any), not by _first,
        # so that bare "all" → toggle, "a all" → add, "r all" → remove.
        if (( _all_req )); then
            _all_prefix="$(printf '%s' "$_line" | sed -E 's/[[:space:]]*[[:alpha:]]+$//' | sed -E 's/^[[:space:]]*//')"
            case "${_all_prefix:0:1}" in
                a|A) _all_mode=add ;;
                r|R) _all_mode=remove ;;
                *)   _all_mode=toggle ;;
            esac
            case "$_all_mode" in
                add)
                    __r_sel=()
                    for _n in "${!__r_opts[@]}"; do __r_sel+=("$((_n + 1))"); done
                    continue ;;
                remove)
                    __r_sel=()
                    continue ;;
                toggle)
                    if (( ${#__r_sel[@]} == ${#__r_opts[@]} )); then
                        __r_sel=()
                    else
                        __r_sel=()
                        for _n in "${!__r_opts[@]}"; do __r_sel+=("$((_n + 1))"); done
                    fi
                    continue ;;
            esac
        fi

        if (( ${#_nums[@]} == 0 )); then
            echo "    (enter a number, e.g. '2', or 'all')"
            continue
        fi

        for n in "${_nums[@]}"; do
            if (( n < 1 || n > ${#__r_opts[@]} )); then
                echo "    (no item $n)"
                continue
            fi
            if _sl_has __r_sel "$n"; then
                # currently selected — remove on remove/toggle
                if [[ "$_mode" == remove || "$_mode" == toggle ]]; then
                    kept=()
                    for x in "${__r_sel[@]:-}"; do
                        [[ -z "$x" || "$x" == "$n" ]] && continue
                        kept+=("$x")
                    done
                    __r_sel=("${kept[@]:-}")
                    if (( ${#__r_sel[@]} == 1 )) && [[ -z "${__r_sel[0]}" ]]; then __r_sel=(); fi
                fi
            else
                # not selected — add on add/toggle
                if [[ "$_mode" == add || "$_mode" == toggle ]]; then
                    __r_sel+=("$n")
                fi
            fi
        done
    done
}
