#!/bin/zsh

# Setup PATH environment variable
setup_path() {
    # Common paths
    local common_paths=(
        "$HOME/bin"
        "$HOME/.local/bin"
        "/usr/local/bin"
        "/usr/local/sbin"
    )

    # Platform-specific paths
    if [[ "$SHELL_PLATFORM" == "OSX" ]] && command -v brew >/dev/null 2>&1; then
        local brew_prefix=$(/opt/homebrew/bin/brew --prefix)
        common_paths+=(
            "$brew_prefix/bin"
            "$brew_prefix/sbin"
        )
    fi

    # Go paths
    if [[ -z "$GOPATH" ]]; then
        export GOPATH="$HOME/workspace/go"
        mkdir -p "$GOPATH"
        common_paths+=("$GOPATH/bin")
        export GOPROXY="https://proxy.golang.org,direct"
    fi

    # Add pyenv paths if available
    if [[ -d "$HOME/.pyenv" ]]; then
        export PYENV_ROOT="$HOME/.pyenv"
        common_paths+=("$PYENV_ROOT/bin")
    fi

    # Construct PATH
    local new_path=()
    for p in "${common_paths[@]}"; do
        if [[ -d "$p" ]]; then
            new_path+=("$p")
        fi
    done

    # Set the new PATH, preserving system paths
    path=($new_path $path)
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
    # Initialize pyenv if available
    if [[ -x "$PYENV_ROOT/bin/pyenv" ]]; then
        eval "$(pyenv init -)"
    fi

    # Python development settings
    export PYTHONDONTWRITEBYTECODE=1  # Prevent Python from writing .pyc files
    export PYTHONUNBUFFERED=1         # Prevent Python from buffering stdout/stderr
}

# Setup development tools and environments
setup_development() {
    # Vagrant settings
    export VAGRANT_DEFAULT_PROVIDER="aws"

    # GCC colors for better output readability
    export GCC_COLORS="error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01"

    # Disable various donation/upgrade messages
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

# Load environment variables from .env file
load_env_file() {
    local env_file="$1"
    if [[ -f "$env_file" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ ! "$line" =~ ^# && "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
                export "$line"
            fi
        done < "$env_file"
    fi
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

    # Load local environment if exists
    load_env_file "$HOME/.env"
}

# Initialize environment when sourced
setup_environment
