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
        "$HOME/.local/bin" \
        "$HOME/.claude/local"

    # Nix profile paths (high priority, after user)
    if [[ -d "/nix" ]]; then
        path_add --user \
            "$HOME/.nix-profile/bin" \
            "/etc/profiles/per-user/${USER}/bin" \
            "/run/wrappers/bin" \
            "/run/current-system/sw/bin" \
            "/nix/var/nix/profiles/default/bin"
    fi

    # Language paths
    path_add --language \
        "${GOBIN:-$HOME/workspace/go/bin}"
    
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
    export PYTHONUNBUFFERED=1
}

# Setup development tools and environments
setup_development() {
    # Platform-specific setup
    if is_osx; then
        # macOS-specific development settings - use static path to avoid slow brew call
        local java_home="/opt/homebrew/opt/openjdk@17"
        if [[ -d "$java_home" ]]; then
            export JAVA_HOME="$java_home"
            path=($JAVA_HOME/bin $path)
        fi
    elif is_linux; then
        # Linux-specific development settings
        export NO_AT_BRIDGE=1
        export GCC_COLORS="error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01"
    fi

    # Common development settings
    export FZF_DEFAULT_OPTS="--height 40% --border"
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
