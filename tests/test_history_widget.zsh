#!/usr/bin/env zsh
source "${0:A:h}/lib.zsh"
if ! have fzf; then
    t_skip "history record selection" "fzf unavailable"
    t_finish
fi

# Real ZLE buffer semantics and real fzf record parsing; --filter selects
# deterministically without driving fzf's UI. Atuin is a controlled producer.
typeset inner="$T_SCRATCH/widget.zsh" out='' backend='' mode=''
cat > "$inner" <<'EOF'
source "$1/.zsh/functions/atuin-fzf-history"
fzf_binary="$2" backend="$3" mode="$4"
multi=$'echo first\necho WIDGET_MATCH\n'
if [[ "$backend" == atuin ]]; then
    atuin() {
        if (( ${@[(Ie)--print0]} )); then
            print -rn -- "$multi"$'\0'
        else
            print -r -- "$multi"
        fi
    }
else
    # Keep atuin off PATH, retaining sed for the old fallback implementation.
    path=("$5")
    fc -p
    HISTSIZE=100
fi
fzf() {
    if [[ "$mode" == cancel ]]; then
        # Drain input and simulate Escape (fzf status 130, no selection).
        local line
        while IFS= read -r line; do :; done
        return 130
    fi
    "$fzf_binary" --filter WIDGET_MATCH "$@"
}
probe() {
    # A second insertion commits the preceding event to the history array
    # in this scripted shell. The unrelated event must not be selected.
    if [[ "$backend" == fallback ]]; then
        print -s -- "$multi"
        print -s -- 'echo unrelated history event'
    fi
    BUFFER='ec --existing-suffix'
    CURSOR=2
    atuin-fzf-history
    if [[ "$mode" == cancel ]]; then
        [[ "$BUFFER" == 'ec --existing-suffix' && $CURSOR == 2 ]] && result=PASS
    else
        [[ "$BUFFER" == "$multi" && $CURSOR == ${#multi} ]] && result=PASS
    fi
    detail="buffer=${(qqq)BUFFER} expected=${(qqq)multi} cursor=$CURSOR"
    zle .accept-line
}
zle -N zle-line-init probe
result=FAIL answer=''
vared answer
print -r -- "RESULT=$result"
print -r -- "$detail"
EOF
typeset fallbackbin="$T_SCRATCH/fallback-bin"
mkdir -p "$fallbackbin"
ln -s "${commands[sed]}" "$fallbackbin/sed"
for backend in atuin fallback; do
    for mode in cancel multiline; do
        if out=$(run_under_pty zsh --no-globalrcs -f -i "$inner" "$ZSH_CONF" "${commands[fzf]}" "$backend" "$mode" "$fallbackbin"); then
            if [[ "$out" == *RESULT=PASS* ]]; then
                t_pass "$backend $mode preserves the expected buffer and cursor (including trailing newline)"
            else
                t_fail "$backend $mode preserves the expected buffer and cursor (including trailing newline)" "$out"
            fi
        else
            t_skip "$backend $mode widget" "PTY unavailable"
        fi
    done
done
t_finish
