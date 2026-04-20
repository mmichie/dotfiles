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

# Function to handle ls commands including the common -altr pattern
_ls_command() {
    if [[ "$*" == "-altr" || "$*" == "-latr" ]]; then
        eza --long --all --sort=modified  --group-directories-first --icons
    else
        eza --group-directories-first --icons "$@"
    fi
}
