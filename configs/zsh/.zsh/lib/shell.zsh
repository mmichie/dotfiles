#!/bin/zsh


# Setup History with advanced features
setup_history() {
    # History file configuration
    export HISTFILE="$HOME/.zsh_history"
    export HISTSIZE=600000        # 20% larger than SAVEHIST for HIST_EXPIRE_DUPS_FIRST cushion
    export SAVEHIST=500000        # History entries saved to disk

    # Enhanced history options
    setopt SHARE_HISTORY          # Share history between all sessions
    setopt EXTENDED_HISTORY       # Save timestamp and duration of command
    setopt HIST_EXPIRE_DUPS_FIRST # Expire duplicate entries first when trimming history
    setopt HIST_IGNORE_ALL_DUPS   # Remove older duplicate from anywhere in history
    setopt HIST_REDUCE_BLANKS     # Remove superfluous blanks (aids deduplication)
    setopt HIST_IGNORE_SPACE      # Don't record an entry starting with a space
    setopt HIST_FIND_NO_DUPS      # Do not display duplicates in history search
    setopt HIST_SAVE_NO_DUPS      # Don't write duplicate entries to history file
    setopt HIST_VERIFY            # Show command with history expansion before running it
    setopt HIST_FCNTL_LOCK        # Use fcntl locking (recommended for concurrent shells)
    setopt HIST_NO_STORE          # Don't store history/fc commands in history

    # Interactive history helpers

    hgrep() {
        if [[ $# -eq 0 ]]; then
            echo "Usage: hgrep <pattern>"
            return 1
        fi
        fc -l 1 -1 | grep --color=auto -i "$@"
    }

    recent() {
        local n=${1:-10}
        history -${n}
    }

    remember() {
        if [[ $# -eq 0 ]]; then
            echo "Usage: remember <command> - Save important command for future reference"
            return 1
        fi
        local remember_file="$HOME/.important_commands"
        echo "$(date +"%Y-%m-%d %H:%M:%S") $@" >> "$remember_file"
        echo "Command saved to $remember_file"
    }

    recalls() {
        local remember_file="$HOME/.important_commands"
        if [[ ! -f "$remember_file" ]]; then
            echo "No saved commands yet."
            return 0
        fi
        if [[ $# -eq 0 ]]; then
            cat "$remember_file"
        else
            grep -i "$@" "$remember_file"
        fi
    }
}

# Dircolors setup
setup_dircolors() {
    if [[ "$TERM" != "dumb" ]]; then
        local dircolors_cmd="$(whence gdircolors 2>/dev/null || whence dircolors 2>/dev/null)"
        local dir_colors="$HOME/.dircolors"

        if [[ -x "$dircolors_cmd" ]] && [[ -r "$dir_colors" ]]; then
            eval "$($dircolors_cmd -b "$dir_colors")"
        elif [[ -x "$dircolors_cmd" ]]; then
            eval "$($dircolors_cmd -b)"
        fi
    fi
}

# Readline setup
setup_readline() {
    # Enable vi command mode
    bindkey -v

    # Basic navigation bindings
    bindkey '^A' beginning-of-line
    bindkey '^E' end-of-line
    bindkey '^D' delete-char
    bindkey '^L' clear-screen
    bindkey '^W' backward-kill-word

    # Word navigation (Alt+Left/Right)
    bindkey '^[b' backward-word
    bindkey '^[f' forward-word
    bindkey '^[[1;3D' backward-word   # Alt+Left in most terminals
    bindkey '^[[1;3C' forward-word    # Alt+Right in most terminals

    # History search bindings
    bindkey '^R' history-incremental-search-backward
    bindkey '^[A' up-line-or-search
    bindkey '^[B' down-line-or-search
}

# Setup completions
# Note: compinit is already called in .zshrc for faster startup
setup_completions() {
    # Completion caching
    zstyle ':completion:*' use-cache on
    zstyle ':completion:*' cache-path "$HOME/.cache/zsh/compcache"

    # Case-insensitive and partial-word completion matching
    zstyle ':completion:*' matcher-list \
        'm:{a-zA-Z}={A-Za-z}' \
        'r:|[._-]=* r:|=*' \
        'l:|=* r:|=*'

    # Menu selection (arrow keys to navigate completions)
    zstyle ':completion:*' menu select
    zmodload zsh/complist

    # Command specific completions
    compdef _command command
    compdef _signal kill
    compdef _user finger pinky

    # Directory handling completions
    compdef _directories cd
    compdef _directories pushd
    compdef _directories mkdir
    compdef _directories rmdir

    # File and job handling completions
    compdef _files ln chmod chown chgrp
    compdef _jobs fg bg disown jobs
}

# Git utilities
git_cleanup() {
    git fetch --prune
    git branch --merged | grep -v "\*" | xargs -n 1 git branch -d
}

# Docker utilities
docker_cleanup() {
    docker system prune -af
    docker volume prune -f
}

setup_shell_options() {
    setopt interactive_comments
    setopt long_list_jobs
    setopt prompt_subst
    setopt AUTO_CD              # If command is a directory name, cd into it
    setopt AUTO_PUSHD          # Make cd push old directory onto directory stack
    setopt PUSHD_IGNORE_DUPS   # Don't push multiple copies of same directory
    setopt PUSHD_SILENT        # Don't print directory stack after pushd/popd
    setopt EXTENDED_GLOB       # Use extended globbing syntax
    setopt GLOB_DOTS            # Include dotfiles in glob matches without needing .*
    setopt NO_CASE_GLOB        # Case insensitive globbing
    setopt NUMERIC_GLOB_SORT   # Sort filenames numerically when possible
    setopt NO_BEEP             # Don't beep on error
    setopt NO_FLOW_CONTROL     # Disable Ctrl-S/Ctrl-Q flow control (frees those keys)
    setopt CORRECT             # Command correction prompt
    setopt COMPLETE_IN_WORD    # Complete from both ends of word
    setopt ALWAYS_TO_END       # Move cursor to end of word after completion
}

# LS colors setup function
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
        if [[ -x "/usr/bin/dircolors" ]]; then
            if [[ -r "$HOME/.dircolors" ]]; then
                eval "$(dircolors -b "$HOME/.dircolors")"
            else
                eval "$(dircolors -b)"
            fi
        fi
    fi

    # Common ls aliases
    alias ll="ls -lh"
    alias la="ls -A"
    alias l="ls -CF"
}

# Setup eza if available, using existing dircolors
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

setup_aliases() {
    # Check if bat is installed and set up alias for cat
    if command -v bat &>/dev/null; then
        alias cat="bat --style=plain --paging=never --wrap=never"
    fi

    # Common aliases
    alias history="history 1" # behave more like bash
    alias gclean="git_cleanup"
    alias dclean="docker_cleanup"
    alias grep="grep --color=auto -d skip"
    alias grpe="grep --color=auto -d skip"
    
    # Configure pagers - use moor if available, otherwise less
    if command -v moor &>/dev/null; then
        # moor has better mouse support and modern features
        alias less="moor"
        alias more="moor"
        alias mr="moor"
        alias mw="moor -wrap"
    else
        # Fallback to less with horizontal scrolling and mouse support
        alias less="less -S --mouse"
        alias more="less"
    fi
    
    # New modern tool aliases
    if command -v duf &>/dev/null; then
        alias df="duf"
    fi
    
    if command -v jless &>/dev/null; then
        alias jl="jless"
    fi
    
    if command -v gping &>/dev/null; then
        alias pg="gping"
    fi
    
    if command -v bandwhich &>/dev/null; then
        alias bw="sudo bandwhich"
    fi
    alias screen="tmux"
    # Nested tmux on a separate socket — gets orange theme via TMUX_LEVEL
    tnest() { TMUX= tmux -L nested new-session -A -s nested "$@"; }
    # ssh hardening lives in ~/.ssh/config (Host *); an alias here would be
    # shadowed by the ssh() wrapper function in ssh.zsh (which uses `command ssh`).
    alias nsr="netstat -rn"
    alias nsa="netstat -an | sed -n '1,/Active UNIX domain sockets/p'"
    alias lsock="sudo lsof -i -P"
    alias keypress="read -s -n1 keypress; echo \$keypress"

    # Directory navigation
    alias :="cd .."
    alias ::="cd ../.."
    alias :::="cd ../../.."
    alias ::::="cd ../../../.."
    alias :::::="cd ../../../../.."
    alias ::::::="cd ../../../../../.."
    alias du='du -h'
    alias mkdir='mkdir -p'
    alias ..='cd ..'
    alias ...='cd ../..'
    alias ....='cd ../../..'
    alias .....='cd ../../../..'
    alias -- -='cd -'
    alias path='echo -e ${PATH//:/\\n}'

    # Suffix aliases
    alias -s {txt,md,markdown,rst}=$EDITOR
    alias -s {gif,jpg,jpeg,png}='open'
    alias -s {html,htm}='open'
}


# Setup zoxide for smart directory navigation
setup_zoxide() {
    if command -v zoxide &>/dev/null; then
        # Initialize zoxide with zsh integration
        eval "$(zoxide init zsh)"
        
        # Configure zoxide
        export _ZO_ECHO=1            # Print the matched directory before navigating to it
        export _ZO_RESOLVE_SYMLINKS=1 # Resolve symlinked directories to their true path
        export _ZO_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zoxide" # Set data directory
        
        alias cdi="zi"               # Interactive directory selection
        
        # Create a function to add current directory with a custom name
        zadd() {
            if [[ $# -eq 0 ]]; then
                echo "Usage: zadd <name> - Add current directory with custom name"
                return 1
            fi
            zoxide add "$(pwd)" --name "$1"
        }
        
        # Create a function to show top directories
        ztop() {
            local count=${1:-10}
            zoxide query --list | head -n "$count"
        }
    fi
}

# Custom function to search atuin history with fzf
atuin-fzf-history() {
    local selected
    if command -v atuin &>/dev/null; then
        # Use atuin to get history and pipe to fzf
        selected=$(atuin search --cmd-only --limit 10000 2>/dev/null | \
            fzf --height 40% \
                --reverse \
                --tac \
                --no-sort \
                --exact \
                --query="${LBUFFER}" \
                --preview 'echo {}' \
                --preview-window down:3:wrap \
                --bind 'ctrl-y:execute-silent(echo -n {} | pbcopy)+abort' \
                --header 'Press CTRL-Y to copy command to clipboard')
    else
        # Fallback to regular fzf history if atuin is not available
        selected=$(fc -rl 1 | \
            fzf --height 40% \
                --reverse \
                --tac \
                --no-sort \
                --exact \
                --query="${LBUFFER}" \
                --preview 'echo {}' \
                --preview-window down:3:wrap \
                --bind 'ctrl-y:execute-silent(echo -n {2..} | pbcopy)+abort' \
                --header 'Press CTRL-Y to copy command to clipboard' | \
            sed 's/^ *[0-9]* *//')
    fi
    
    if [[ -n "$selected" ]]; then
        LBUFFER="$selected"
        zle redisplay
    fi
    zle reset-prompt
}

# Create the widget
zle -N atuin-fzf-history

init_shell() {
    setup_shell_options
    setup_aliases
    setup_dircolors
    setup_readline
    setup_completions
    setup_history
    # eza with internal fallback to setup_ls_colors when eza is absent
    setup_eza
    # Setup zoxide for smarter directory navigation
    setup_zoxide

    # Bind Ctrl-R to a better history search experience using fzf if available
    if command -v fzf &>/dev/null; then
        # Use custom atuin+fzf history search
        bindkey '^R' atuin-fzf-history

        # Ctrl-T for file selection
        bindkey '^T' fzf-file-widget

        # Alt-C for directory navigation
        bindkey '^[c' fzf-cd-widget
    fi

    # Bind Ctrl-F to tmux-sessionizer for quick project switching
    if command -v tmux-sessionizer &>/dev/null; then
        bindkey -s '^F' 'tmux-sessionizer\n'
    fi
}
