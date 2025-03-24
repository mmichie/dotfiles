#!/bin/zsh

# Setup PATH environment variable
setup_path() {
    # Initialize path array if not already set
    typeset -U path

    # Common system paths that should exist on all platforms
    local system_paths=(
        /usr/local/bin
        /usr/bin
        /bin
        /usr/sbin
        /sbin
    )

    # Platform-specific paths
    if is_osx; then
        system_paths+=(
            /opt/X11/bin
        )

        # Homebrew on macOS
        if has_capability "homebrew"; then
            local brew_prefix=$(/opt/homebrew/bin/brew --prefix)
            path=(
                $brew_prefix/bin
                $brew_prefix/sbin
                $path
            )

            # Java from Homebrew
            if [[ -d "$brew_prefix/opt/openjdk@17" ]]; then
                path=($brew_prefix/opt/openjdk@17/bin $path)
                export JAVA_HOME="$brew_prefix/opt/openjdk@17"
            fi
        fi
    elif is_linux; then
        # Linux specific paths
        system_paths+=(
            /usr/local/games
            /usr/games
        )

        # WSL2 specific
        if [[ -f /proc/sys/fs/binfmt_misc/WSLInterop ]]; then
            system_paths+=(
                /mnt/c/Windows/System32
                /mnt/c/Windows
            )
        fi

        # Linuxbrew
        if has_capability "homebrew"; then
            eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        fi
    fi

    # Set up pyenv path if available
    if [[ -d "$HOME/.pyenv" ]]; then
        export PYENV_ROOT="$HOME/.pyenv"
        path=(
            $PYENV_ROOT/bin
            $path
        )
        # Note: pyenv shims will be added by the lazy loader when needed
    fi

    # Add Go paths if needed
    if [[ -z "$GOPATH" ]]; then
        export GOPATH="$HOME/workspace/go"
        export GOBIN="$GOPATH/bin"
        path=($path $GOBIN)
        export GOPROXY="https://proxy.golang.org,direct"
    fi

    # Add user paths - these should be consistent across platforms
    local user_paths=(
        "$HOME/bin"
        "$HOME/.local/bin"
    )

    # Helper function to check if a path is already in $path
    path_exists() {
        local check_path="$1"
        local p
        for p in $path; do
            [[ "$p" == "$check_path" ]] && return 0
        done
        return 1
    }

    # Construct the final path
    # 1. Start with user paths
    for user_path in $user_paths; do
        if [[ -d "$user_path" ]]; then
            path=($user_path $path)
        fi
    done

    # 2. Add system paths if they're not already present
    for sys_path in $system_paths; do
        if [[ -d "$sys_path" ]] && ! path_exists "$sys_path"; then
            path+=$sys_path
        fi
    done

    # Ensure unique entries while preserving order
    typeset -U path

    # Export the updated PATH
    export PATH="${(j.:.)path}"
}

# Setup locale and timezone settings
setup_locale() {
    # Set default locale to UTF-8
    export LC_ALL="en_US.UTF-8"
    export LANG="en_US.UTF-8"

    # Set timezone
    export TZ="US/Pacific"
}

# Configure default editors
setup_editors() {
    # Check for neovim first
    if command -v nvim >/dev/null 2>&1; then
        export EDITOR="nvim"
        export VISUAL="nvim"
        alias vim='nvim'
        alias vi='nvim'
    else
        export EDITOR="vim -f"
        export VISUAL="vim -f"
    fi

    # Set P4 editor
    export P4EDITOR="$EDITOR"
}

# Setup Python environment
setup_python() {
    # Python development settings
    export PYTHONUNBUFFERED=1
    
    # Other Python settings can be added here
    # pyenv is now lazy loaded in setup_pyenv()
}

# Setup Node Version Manager (nvm) - lazy loading
setup_nvm() {
    # Set NVM_DIR to the Homebrew location
    export NVM_DIR="$HOME/.nvm"

    # Create .nvm directory if it doesn't exist
    mkdir -p "$NVM_DIR"

    # Only set up nvm brew path - actual loading happens lazily
    if has_capability "homebrew"; then
        export NVM_BREW_PATH="/opt/homebrew/opt/nvm"
    fi

    # Define lazy loading functions
    nvm() {
        unset -f nvm node npm npx yarn
        
        # Source the nvm script
        if [[ -s "$NVM_BREW_PATH/nvm.sh" ]]; then
            source "$NVM_BREW_PATH/nvm.sh"
            # Source completions 
            [[ -s "$NVM_BREW_PATH/etc/bash_completion.d/nvm" ]] && source "$NVM_BREW_PATH/etc/bash_completion.d/nvm"
        fi
        
        # Call the newly loaded nvm function with the provided arguments
        nvm "$@"
    }

    # Lazy load proxies for common Node commands
    node() {
        unset -f nvm node npm npx yarn
        
        # Source the nvm script
        if [[ -s "$NVM_BREW_PATH/nvm.sh" ]]; then
            source "$NVM_BREW_PATH/nvm.sh"
            # Source completions 
            [[ -s "$NVM_BREW_PATH/etc/bash_completion.d/nvm" ]] && source "$NVM_BREW_PATH/etc/bash_completion.d/nvm"
        fi
        
        # Call the command now
        node "$@"
    }

    npm() {
        unset -f nvm node npm npx yarn
        
        # Source the nvm script
        if [[ -s "$NVM_BREW_PATH/nvm.sh" ]]; then
            source "$NVM_BREW_PATH/nvm.sh"
            # Source completions 
            [[ -s "$NVM_BREW_PATH/etc/bash_completion.d/nvm" ]] && source "$NVM_BREW_PATH/etc/bash_completion.d/nvm"
        fi
        
        # Call the command now
        npm "$@"
    }

    npx() {
        unset -f nvm node npm npx yarn
        
        # Source the nvm script
        if [[ -s "$NVM_BREW_PATH/nvm.sh" ]]; then
            source "$NVM_BREW_PATH/nvm.sh"
            # Source completions 
            [[ -s "$NVM_BREW_PATH/etc/bash_completion.d/nvm" ]] && source "$NVM_BREW_PATH/etc/bash_completion.d/nvm"
        fi
        
        # Call the command now
        npx "$@"
    }

    yarn() {
        unset -f nvm node npm npx yarn
        
        # Source the nvm script
        if [[ -s "$NVM_BREW_PATH/nvm.sh" ]]; then
            source "$NVM_BREW_PATH/nvm.sh"
            # Source completions 
            [[ -s "$NVM_BREW_PATH/etc/bash_completion.d/nvm" ]] && source "$NVM_BREW_PATH/etc/bash_completion.d/nvm"
        fi
        
        # Call the command now
        yarn "$@"
    }
}

# Setup development tools and environments
setup_development() {
    # Platform-specific setup
    if is_osx; then
        # macOS-specific development settings
        if has_capability "homebrew"; then
            local brew_java_home="$(/opt/homebrew/bin/brew --prefix openjdk@17 2>/dev/null)"
            if [[ -d "$brew_java_home" ]]; then
                export JAVA_HOME="$brew_java_home"
                path=($JAVA_HOME/bin $path)
            fi
        fi
    elif is_linux; then
        # Linux-specific development settings
        export NO_AT_BRIDGE=1
        export GCC_COLORS="error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01"
    fi

    # Common development settings
    export VAGRANT_DEFAULT_PROVIDER="aws"
    export GCC_COLORS="error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01"
    export ENV_DISABLE_DONATION_MSG=1
}


# Setup XDG Base Directory paths
setup_xdg() {
    export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
    export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
    export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
    export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

    # Create directories if they don't exist
    mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME"
}

# Setup terminal environment
setup_terminal() {
    # Check if we're running interactively
    [[ $- != *i* ]] && return

    # Terminal specific settings
    case $TERM in
        xterm*|screen*)
            # Enable terminal features
            export COLORTERM="${COLORTERM:-truecolor}"
            ;;
    esac
}

# Setup miscellaneous environment variables
setup_misc() {
    # Set less options
    export LESS="-R -F -X"
    export LESSHISTFILE="$XDG_CACHE_HOME/less/history"
    mkdir -p "$(dirname "$LESSHISTFILE")"

    # Set default permissions for new files
    umask 022

    # Ensure clean command hash
    hash -r
}

# Load environment variables from .env file
load_env_file() {
    local env_file="$1"

    [[ ! -f "$env_file" ]] && return 1

    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" = \#* ]] && continue

        # Only process valid environment variable assignments
        if [[ "$line" = [A-Za-z_]*([A-Za-z0-9_])=* ]]; then
            # Remove any surrounding quotes from the value
            local cleaned_line="${line//\"/}"  # Remove double quotes
            cleaned_line="${cleaned_line//\'/}"  # Remove single quotes
            export "$cleaned_line"
        fi
    done < "$env_file"
}

# Main environment setup function
setup_environment() {
    setup_xdg
    setup_path
    setup_locale
    setup_editors
    setup_python
    setup_nvm
    setup_development
    setup_terminal
    setup_misc
    setup_go_directories

    export WORDCHARS='*?_-.[]~=&;!#$%^(){}<>'
    export TIMEFMT=$'\nreal\t%*E\nuser\t%*U\nsys\t%*S'
    export REPORTTIME=10
    export KEYTIMEOUT=1  # Reduces delay in vi-mode

    # History improvements
    export HISTIGNORE="ls:cd:cd -:pwd:exit:date:* --help"
    export HISTCONTROL="ignoreboth:erasedups"

    # Load local environment if exists
    load_env_file "$HOME/.env"
}

# Setup Go directories
setup_go_directories() {
    [[ -n "$GOBIN" ]] && mkdir -p "$GOBIN"
}

# Initialize environment when sourced
setup_environment
