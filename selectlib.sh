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
# Loops: lists the current selection + all options, then reads
#   [c]onfirm · [a]dd <nums> · [r]emove <nums>  (Enter = confirm).
review_selection() {
    local -n __r_opts="$1"
    local -n __r_sel="$2"
    local label="${3:-item}"
    local action rest n x

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
        read -rp "[c]onfirm · [a]dd <nums> · [r]emove <nums>: " action rest

        case "$action" in
            ""|c|C)
                return 0
                ;;
            a|A)
                for n in $rest; do
                    if [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#__r_opts[@]} )); then
                        _sl_has __r_sel "$n" || __r_sel+=("$n")
                    else
                        echo "    (ignored '$n')"
                    fi
                done
                ;;
            r|R)
                local kept=() keep
                for x in "${__r_sel[@]:-}"; do
                    [[ -z "$x" ]] && continue
                    keep=1
                    for n in $rest; do [[ "$x" == "$n" ]] && keep=0; done
                    if (( keep )); then kept+=("$x"); fi
                done
                __r_sel=("${kept[@]:-}")
                if (( ${#__r_sel[@]} == 1 )) && [[ -z "${__r_sel[0]}" ]]; then __r_sel=(); fi
                ;;
            *)
                echo "    (use 'c', 'a <nums>', or 'r <nums>')"
                ;;
        esac
    done
}
