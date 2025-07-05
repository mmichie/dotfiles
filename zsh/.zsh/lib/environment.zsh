#!/bin/zsh

# Setup PATH environment variable
setup_path() {
    # Load the path manager
    source "$SHELL_LIB_DIR/path_manager.zsh"
    
    # Initialize path management
    path_init
    
    # User paths (highest priority)
    path_add --user \
        "$HOME/bin" \
        "$HOME/.local/bin"
    
    # Language paths
    path_add --language \
        "${GOBIN:-$HOME/workspace/go/bin}" \
        "$HOME/.cargo/bin"
    
    # Add lazy-loaded language paths (may not exist yet)
    path_add_lazy language \
        "$HOME/.pyenv/shims" \
        "$HOME/.pyenv/bin"
    
    # Development tools
    if is_osx && has_capability "homebrew"; then
        local brew_prefix=$(/opt/homebrew/bin/brew --prefix 2>/dev/null || echo "/opt/homebrew")
        path_add --tools \
            "$brew_prefix/bin" \
            "$brew_prefix/sbin"
        
        # Java from Homebrew
        if [[ -d "$brew_prefix/opt/openjdk@17" ]]; then
            path_add --tools "$brew_prefix/opt/openjdk@17/bin"
            export JAVA_HOME="$brew_prefix/opt/openjdk@17"
        fi
    elif is_linux && has_capability "homebrew"; then
        # Linuxbrew paths
        path_add --tools \
            "/home/linuxbrew/.linuxbrew/bin" \
            "/home/linuxbrew/.linuxbrew/sbin"
    fi
    
    # Add lazy-loaded tool paths
    path_add_lazy tools \
        "$HOME/google-cloud-sdk/bin"
    
    # System overrides
    path_add --system \
        "/usr/local/bin" \
        "/usr/local/sbin"
    
    # Platform-specific system paths
    if is_osx; then
        path_add --system "/opt/X11/bin"
    elif is_linux; then
        path_add --system \
            "/usr/local/games" \
            "/usr/games"
        
        # WSL2 specific
        if [[ -f /proc/sys/fs/binfmt_misc/WSLInterop ]]; then
            path_add --system \
                "/mnt/c/Windows/System32" \
                "/mnt/c/Windows"
        fi
    fi
    
    # Preserve existing system paths from path_helper
    path_add_system
    
    # Build the final PATH
    path_build
    
    # Set up Go environment variables
    export GOPATH="${GOPATH:-$HOME/workspace/go}"
    export GOBIN="${GOBIN:-$GOPATH/bin}"
    export GOPROXY="${GOPROXY:-https://proxy.golang.org,direct}"
    
    # Set up pyenv root if directory exists
    [[ -d "$HOME/.pyenv" ]] && export PYENV_ROOT="$HOME/.pyenv"
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

# Setup npm-installed binaries with lazy loading
setup_npm_binaries() {
    # Create function to handle any npm-installed binary that's not found
    function command_not_found_handler() {
        local cmd="$1"
        
        # Check if the command might be in the npm bin directory
        local npm_bin_path="$HOME/.npm/bin"
        local node_modules_bin="$HOME/node_modules/.bin"
        local npm_binary=""
        
        # If npm is already initialized, these paths should already be in PATH
        if ! command -v "$cmd" &>/dev/null; then
            # Try initializing npm once
            if ! command -v npm &>/dev/null || [[ "$(type npm)" == *"function"* ]]; then
                # Run npm to ensure it's fully initialized
                npm --version &>/dev/null
                
                # Now check if the command exists
                if command -v "$cmd" &>/dev/null; then
                    # Command is now available, execute it
                    "$cmd" "${@:2}"
                    return $?
                fi
            fi
        fi
        
        # If we get here, command wasn't found even after npm initialization
        echo "zsh: command not found: $cmd" >&2
        return 127
    }
}

# Main environment setup function
setup_environment() {
    setup_xdg
    setup_path
    setup_locale
    setup_editors
    setup_python
    setup_nvm
    setup_npm_binaries
    setup_development
    setup_terminal
    setup_misc
    setup_go_directories
    
    # Setup platform-specific executables after PATH is configured
    if type setup_platform_executables >/dev/null 2>&1; then
        setup_platform_executables
    fi

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

# Don't initialize here - let .zshrc call setup_environment
# setup_environment
