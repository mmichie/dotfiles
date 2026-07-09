#!/bin/zsh

# LS aliases + BSD-ls fallback. LS_COLORS comes from vivid in setup_integrations.
setup_ls_colors() {
    if is_osx; then
        if command -v gls &>/dev/null; then
            alias ls="gls --color=auto -F"
        else
            export CLICOLOR=1
            export LSCOLORS="ExGxFxdaCxDaDahbadacec"
            alias ls="ls -F"
        fi
    elif is_linux; then
        alias ls="ls --color=auto -F"
    fi

    # Common ls aliases
    alias ll="ls -lh"
    alias la="ls -A"
    alias l="ls -CF"
}

# Setup eza if available
setup_eza() {
    # Only proceed if eza is installed
    if ! command -v eza &>/dev/null; then
        setup_ls_colors
        return
    fi

    export EZA_COLORS="ur=0:uw=0:ux=0:ue=0:gr=0:gw=0:gx=0:tr=0:tw=0:tx=0:su=0:sf=0"

    # Core eza aliases with standard formatting
    alias ls='_ls_command'  # Override ls with our custom function
    alias ll='eza --long --header --icons --git --group-directories-first'
    alias la='eza --long --header --icons --git --group-directories-first --all'
    alias lt='eza --tree --level=2 --icons'
    alias ltt='eza --tree --level=3 --icons'
    alias lttt='eza --tree --level=4 --icons'
    alias l='eza --long --header --icons --git --group-directories-first'
    alias l.='eza --long --header --icons --git --all --group-directories-first .*'

    # Simple alias for the common pattern
    alias lstr='eza --long --all --sort=modified --reverse'

    # Additional aliases for different views
    alias lm='eza --long --header --icons --git --sort=modified'
    alias lk='eza --long --header --icons --git --sort=size'
    alias lc='eza --long --header --icons --git --sort=created'
    alias lx='eza --long --header --icons --git --sort=extension'
    alias lr='eza --long --header --icons --git --recurse'
    alias ld='eza --only-dirs --icons'

    # Git-specific aliases
    alias lg='eza --long --header --icons --git --git-ignore'
    alias lsg='eza --long --header --icons --git --git-ignore --sort=size'
}

# GNU-ls muscle memory: translate short-flag clusters (ls -altr, -lt, -lS,
# any permutation) onto eza's argument language. The tools disagree on sort
# direction — GNU -t/-S list newest/largest FIRST, eza sorts ascending, so
# the reverse bit is (GNU-descending XOR r) — and on letters: -h is human
# sizes in GNU (eza's default) but --header in eza, so it is dropped.
# Returns 0 with the eza argv in $reply, or 1 for any flag outside the map;
# the caller must then run real ls, so unmapped GNU flags keep GNU semantics
# instead of hitting eza errors or silently wrong order. Long options pass
# through untranslated: they are typed deliberately, not muscle memory, and
# the common ones (--color, --time-style, --group-directories-first) agree.
_ls_gnu_to_eza() {
    reply=()
    local -a out paths
    local arg c sort='' gnu_desc=0 rev=0 ddash=0
    local -i i
    for arg in "$@"; do
        if (( ddash )) || [[ "$arg" != -?* ]]; then
            paths+=("$arg")
            continue
        fi
        if [[ "$arg" == -- ]]; then
            ddash=1
            continue
        fi
        if [[ "$arg" == --* ]]; then
            out+=("$arg")
            continue
        fi
        for (( i = 2; i <= ${#arg}; i++ )); do
            c="${arg[i]}"
            case "$c" in
                a) out+=(--all) ;;
                A) out+=(--almost-all) ;;
                l) out+=(--long) ;;
                1) out+=(--oneline) ;;
                d) out+=(--list-dirs) ;;
                F) out+=(--classify) ;;
                R) out+=(--recurse) ;;
                i) out+=(--inode) ;;
                h) ;;
                t) sort=modified; gnu_desc=1 ;;
                S) sort=size; gnu_desc=1 ;;
                U) sort=none; gnu_desc=0 ;;
                r) rev=1 ;;
                *) return 1 ;;
            esac
        done
    done
    [[ -n "$sort" ]] && out+=(--sort="$sort")
    (( gnu_desc ^ rev )) && out+=(--reverse)
    reply=("${out[@]}")
    (( ${#paths} )) && reply+=(-- "${paths[@]}")
    return 0
}

# ls dispatcher: translated clusters go to eza (house style); anything the
# translator refuses goes to real GNU ls so semantics never silently drift.
_ls_command() {
    local -a reply
    if _ls_gnu_to_eza "$@"; then
        eza --group-directories-first --icons "${reply[@]}"
    elif (( $+commands[gls] )); then
        command gls --color=auto "$@"
    elif [[ "$OSTYPE" == darwin* ]]; then
        CLICOLOR=1 command ls "$@"
    else
        command ls --color=auto "$@"
    fi
}

# eza has internal fallback to setup_ls_colors when eza is absent
setup_eza
