#!/bin/zsh


# Setup History with advanced features
setup_history() {
    # History file configuration
    export HISTFILE="$HOME/.zsh_history"
    export HISTSIZE=1000000       # Very large history in memory
    export SAVEHIST=1000000       # Very large history on disk

    # Enhanced history options
    setopt SHARE_HISTORY          # Share history between all sessions
    setopt INC_APPEND_HISTORY_TIME # Add timestamps to history
    setopt EXTENDED_HISTORY       # Save timestamp and duration of command
    setopt HIST_EXPIRE_DUPS_FIRST # Expire duplicate entries first when trimming history
    setopt HIST_IGNORE_ALL_DUPS   # Ignore duplicated entries
    setopt HIST_IGNORE_DUPS       # Don't record a command that's a duplicate of the previous command
    setopt HIST_REDUCE_BLANKS     # Remove superfluous blanks
    setopt HIST_IGNORE_SPACE      # Don't record an entry starting with a space
    setopt HIST_FIND_NO_DUPS      # Do not display duplicates in history search
    setopt HIST_SAVE_NO_DUPS      # Don't write duplicate entries to history file
    setopt HIST_VERIFY            # Show command with history expansion before running it
    setopt HIST_FCNTL_LOCK        # Use better file locking for the history file
    
    # Add functions for better history searching and management
    
    # Function to search history with a pattern
    hgrep() {
        if [[ $# -eq 0 ]]; then
            echo "Usage: hgrep <pattern>"
            return 1
        fi
        
        fc -l 1 -1 | grep --color=auto -i "$@"
    }
    
    # Function to view recent commands
    recent() {
        local n=${1:-10}
        history -${n}
    }
    
    # Function to save important commands to a separate file
    remember() {
        if [[ $# -eq 0 ]]; then
            echo "Usage: remember <command> - Save important command for future reference"
            return 1
        fi
        
        local remember_file="$HOME/.important_commands"
        echo "$(date +"%Y-%m-%d %H:%M:%S") $@" >> "$remember_file"
        echo "Command saved to $remember_file"
    }
    
    # Function to view saved important commands
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
    
    # Setup weekly backups of history
    [[ ! -d "$HOME/.zsh_history_backups" ]] && mkdir -p "$HOME/.zsh_history_backups"
    
    # Function to create dated backup of shell history
    backup_history() {
        local backup_file="$HOME/.zsh_history_backups/zsh_history_$(date +"%Y%m%d").gz"
        cp "$HISTFILE" "$HISTFILE.bak"
        gzip -c "$HISTFILE.bak" > "$backup_file"
        rm "$HISTFILE.bak"
        
        # Clean up old backups (keep last 30)
        ls -t "$HOME/.zsh_history_backups" | tail -n +31 | xargs -I {} rm "$HOME/.zsh_history_backups/{}" 2>/dev/null
    }
    
    # Add to weekly cron if not already there
    add_history_backup_cron() {
        local cron_cmd="0 0 * * 0 . $HOME/.zshrc; backup_history >/dev/null 2>&1"
        (sudo crontab -l 2>/dev/null | grep -v "backup_history" ; echo "$cron_cmd") | sudo crontab -
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

    # History search bindings
    bindkey '^R' history-incremental-search-backward
    bindkey '^[A' up-line-or-search
    bindkey '^[B' down-line-or-search
}

# Setup completions
setup_completions() {
    autoload -Uz compinit
    compinit

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

# pyenv setup - lazy loading
setup_pyenv() {
    export PYENV_ROOT="$HOME/.pyenv"
    
    # Note: PATH setup for pyenv is now handled by path_manager.zsh
    # We only set up lazy loading here
    
    # Export basic pyenv environment settings
    export PYENV_DISABLE_COMPLETIONS=1
    
    # Create lazy loading function for pyenv
    pyenv() {
        unset -f pyenv python python3 pip pip3
        
        # Now do full initialization
        if [[ -x "$PYENV_ROOT/bin/pyenv" ]]; then
            # Initialize pyenv without completions
            eval "$(pyenv init - --no-completion)"
            
            # Add custom completion directory to fpath
            fpath=(~/.zsh/functions $fpath)
            
            # Reload completions
            autoload -Uz compinit && compinit
        fi
        
        # Call the real pyenv command
        pyenv "$@"
    }
    
    # Lazy load proxies for Python commands
    python() {
        unset -f pyenv python python3 pip pip3
        
        # Initialize pyenv
        if [[ -x "$PYENV_ROOT/bin/pyenv" ]]; then
            eval "$(pyenv init - --no-completion)"
        fi
        
        # Call the command
        python "$@"
    }
    
    python3() {
        unset -f pyenv python python3 pip pip3
        
        # Initialize pyenv
        if [[ -x "$PYENV_ROOT/bin/pyenv" ]]; then
            eval "$(pyenv init - --no-completion)"
        fi
        
        # Call the command
        python3 "$@"
    }
    
    pip() {
        unset -f pyenv python python3 pip pip3
        
        # Initialize pyenv
        if [[ -x "$PYENV_ROOT/bin/pyenv" ]]; then
            eval "$(pyenv init - --no-completion)"
        fi
        
        # Call the command
        pip "$@"
    }
    
    pip3() {
        unset -f pyenv python python3 pip pip3
        
        # Initialize pyenv
        if [[ -x "$PYENV_ROOT/bin/pyenv" ]]; then
            eval "$(pyenv init - --no-completion)"
        fi
        
        # Call the command
        pip3 "$@"
    }
}

# Use ZSH hooks instead of cron for history backup
setup_history_backup_hooks() {
    # Create a function that will be called when the shell exits
    backup_on_logout() {
        # Check if we've done a backup in the last 24 hours
        local backup_dir="$HOME/.shell_history_backups"
        local last_backup=$(ls -t "$backup_dir"/zsh_history_*.tar.gz 2>/dev/null | head -1)
        local now=$(date +%s)
        
        # If there's no backup, create one
        if [[ -z "$last_backup" ]]; then
            backup_shell_history
            return
        fi
        
        # Extract timestamp from filename (e.g., zsh_history_20240111123456.tar.gz)
        local basename=$(basename "$last_backup")
        local timestamp_part=${basename#zsh_history_}
        timestamp_part=${timestamp_part%.tar.gz}
        
        # Validate timestamp format
        if [[ ! "$timestamp_part" =~ ^[0-9]{14}$ ]]; then
            backup_shell_history
            return
        fi
        
        # Parse the timestamp on macOS
        local year=${timestamp_part:0:4}
        local month=${timestamp_part:4:2}
        local day=${timestamp_part:6:2}
        local hour=${timestamp_part:8:2}
        local minute=${timestamp_part:10:2}
        local second=${timestamp_part:12:2}
        
        # Convert to epoch time using macOS date syntax
        local last_backup_time=$(date -j -f "%Y-%m-%d %H:%M:%S" "$year-$month-$day $hour:$minute:$second" +%s 2>/dev/null)
        
        # If parsing failed or backup is older than 24 hours, create new backup
        if [[ -z "$last_backup_time" ]] || [[ $((now - last_backup_time)) -gt 86400 ]]; then
            backup_shell_history
        fi
    }
    
    # Register the function to be called when the shell exits
    zshexit() {
        backup_on_logout
    }
}

# Backup shell history
backup_shell_history() {
    local backup_dir="$HOME/.shell_history_backups"
    mkdir -p "$backup_dir"
    local timestamp=$(date +"%Y%m%d%H%M%S")
    tar -czf "$backup_dir/zsh_history_$timestamp.tar.gz" -C "$HOME" .zsh_history
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
    setopt rm_star_silent
    setopt AUTO_CD              # If command is a directory name, cd into it
    setopt AUTO_PUSHD          # Make cd push old directory onto directory stack
    setopt PUSHD_IGNORE_DUPS   # Don't push multiple copies of same directory
    setopt PUSHD_SILENT        # Don't print directory stack after pushd/popd
    setopt EXTENDED_GLOB       # Use extended globbing syntax
    setopt NO_CASE_GLOB        # Case insensitive globbing
    setopt NUMERIC_GLOB_SORT   # Sort filenames numerically when possible
    setopt NO_BEEP             # Don't beep on error
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

# Setup Neovim aliases if available
setup_nvim_alias() {
    # Check if nvim is installed
    if command -v nvim >/dev/null 2>&1; then
        alias vim='nvim'
        alias vi='nvim'
        export EDITOR='nvim'
        export VISUAL='nvim'
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
    alias ssh="ssh -A -o StrictHostKeyChecking=accept-new -o ServerAliveInterval=60 -o ServerAliveCountMax=3 -o ConnectTimeout=10 -o VisualHostKey=yes -o IdentitiesOnly=yes"
    alias nsr="netstat -rn"
    alias nsa="netstat -an | sed -n '1,/Active UNIX domain sockets/p'"
    alias lsock="sudo /usr/sbin/lsof -i -P"
    alias keypress="read -s -n1 keypress; echo \$keypress"
    alias loadenv='export $(grep -v "^#" .env | xargs)'

    # Directory navigation
    alias :="cd .."
    alias ::="cd ../.."
    alias :::="cd ../../.."
    alias ::::="cd ../../../.."
    alias :::::="cd ../../../../.."
    alias ::::::="cd ../../../../../.."
    # alias df='df -h'  # Commented out - using duf instead
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
    setup_nvim_alias
}


# Setup fzf-tab plugin for enhanced tab completion
setup_fzf_tab() {
    local fzf_tab_path="$HOME/.zsh/plugins/fzf-tab"
    if [[ -d "$fzf_tab_path" ]]; then
        source "$fzf_tab_path/fzf-tab.plugin.zsh"
        
        # Configure fzf-tab
        zstyle ':completion:*:descriptions' format '[%d]'
        zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
        zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls -1 --color=always $realpath'
        zstyle ':fzf-tab:complete:*:*' fzf-preview 'less ${(Q)realpath}'
        zstyle ':fzf-tab:*' switch-group ',' '.'
        
        # Use bat for previews if available
        if command -v bat &>/dev/null; then
            zstyle ':fzf-tab:complete:*:*' fzf-preview 'bat --color=always --style=numbers --line-range=:500 ${(Q)realpath} 2>/dev/null || ls -1 --color=always ${(Q)realpath}'
        fi
    fi
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
        
        # Create aliases to teach users about functionality
        # alias cd="z"                 # Override cd with z (commented out - was breaking PWD tracking)
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
    # Try eza first, fall back to regular ls colors
    setup_eza || setup_ls_colors
    # Setup fzf-tab after completions are initialized
    setup_fzf_tab
    # Setup zoxide for smarter directory navigation
    setup_zoxide
    
    # Set up history backup via shell exit hook
    setup_history_backup_hooks
    
    # Bind Ctrl-R to a better history search experience using fzf if available
    if command -v fzf &>/dev/null; then
        # Use custom atuin+fzf history search
        bindkey '^R' atuin-fzf-history
        
        # Ctrl-T for file selection
        bindkey '^T' fzf-file-widget
        
        # Alt-C for directory navigation
        bindkey '^[c' fzf-cd-widget
    fi
}
