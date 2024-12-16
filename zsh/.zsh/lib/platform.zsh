#!/bin/zsh

# Detect architecture (x86_64, arm64, etc.)
detect_architecture() {
    local arch=$(uname -m)
    case "$arch" in
        x86_64) echo 'x86_64' ;;
        aarch64|arm64) echo 'arm64' ;;  # Handle both identifiers for ARM64
        *) echo 'unknown' ;;
    esac
}

# Detect shell platform (LINUX, OSX, BSD, etc.)
detect_shell_platform() {
    case "$OSTYPE" in
        linux*) echo 'LINUX' ;;
        darwin*) echo 'OSX' ;;
        freebsd*) echo 'BSD' ;;
        cygwin*) echo 'CYGWIN' ;;
        *) echo 'OTHER' ;;
    esac
}

# Set up platform-specific configurations
setup_platform_specific() {
    local os_type=$(detect_shell_platform)

    case "$os_type" in
        OSX)
            # Homebrew configuration
            export HOMEBREW_NO_ANALYTICS=1
            if command -v brew >/dev/null 2>&1; then
                path=($(/opt/homebrew/bin/brew --prefix)/bin $(/opt/homebrew/bin/brew --prefix)/sbin $path)

                # Homebrew completions
                if [[ -r "$(/opt/homebrew/bin/brew --prefix)/share/zsh/site-functions/_brew" ]]; then
                    fpath=($fpath $(/opt/homebrew/bin/brew --prefix)/share/zsh/site-functions)
                    autoload -Uz compinit && compinit
                fi
            fi

            # iTerm2 integration
            [[ -r "$HOME/.iterm2_shell_integration.zsh" ]] && source "$HOME/.iterm2_shell_integration.zsh"

            # Java setup for macOS
            local brew_java_home="$(/opt/homebrew/bin/brew --prefix openjdk@17 2>/dev/null)"
            if [[ -d "$brew_java_home" ]]; then
                export JAVA_HOME="$brew_java_home"
                path=($JAVA_HOME/bin $path)
            fi
            ;;

        LINUX)
            # Linux-specific environment variables
            export NO_AT_BRIDGE=1

            # Color support for ls and grep
            if [[ -x "/usr/bin/dircolors" ]]; then
                if [[ -r "$HOME/.dircolors" ]]; then
                    eval "$(dircolors -b "$HOME/.dircolors")"
                else
                    eval "$(dircolors -b)"
                fi
            fi

            # GCC colors
            export GCC_COLORS="error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01"
            ;;
    esac
}

# Set up platform-specific executables
setup_platform_executables() {
    local os_type=$(detect_shell_platform)
    local arch_type=$(detect_architecture)
    local platform_cmd="${os_type}-${arch_type}"

    # Setup FZF
    setup_fzf "$platform_cmd"

    # Setup Intu
    setup_intu "$platform_cmd"

    # Setup clipboard functionality
    setup_clipboard "$platform_cmd"
}

# Setup FZF for the current platform
setup_fzf() {
    local platform_cmd=$1
    local fzf_cmd
    local common_fzf_link="$HOME/bin/fzf"

    case "$platform_cmd" in
        OSX-x86_64) fzf_cmd="$HOME/bin/fzf-darwin-amd64" ;;
        OSX-arm64) fzf_cmd="$HOME/bin/fzf-darwin-arm64" ;;
        LINUX-arm64) fzf_cmd="$HOME/bin/fzf-linux-arm64" ;;
        LINUX-x86_64) fzf_cmd="$HOME/bin/fzf-linux-amd64" ;;
    esac

    if [[ -n "$fzf_cmd" ]] && [[ -x "$fzf_cmd" ]]; then
        [[ ! -L "$common_fzf_link" ]] || [[ "$(readlink -- "$common_fzf_link")" != "$fzf_cmd" ]] && \
            ln -sf "$fzf_cmd" "$common_fzf_link"
    fi
}

# Setup Intu for the current platform
setup_intu() {
    local platform_cmd=$1
    local intu_cmd
    local common_intu_link="$HOME/bin/intu"

    case "$platform_cmd" in
        OSX-x86_64) intu_cmd="$HOME/bin/intu-darwin-amd64" ;;
        OSX-arm64) intu_cmd="$HOME/bin/intu-darwin-arm64" ;;
        LINUX-arm64) intu_cmd="$HOME/bin/intu-linux-arm64" ;;
        LINUX-x86_64) intu_cmd="$HOME/bin/intu-linux-amd64" ;;
        *)
            echo "Unsupported platform for intu: $platform_cmd"
            return 1
            ;;
    esac

    if [[ -n "$intu_cmd" ]] && [[ -x "$intu_cmd" ]]; then
        [[ ! -L "$common_intu_link" ]] || [[ "$(readlink -- "$common_intu_link")" != "$intu_cmd" ]] && \
            ln -sf "$intu_cmd" "$common_intu_link"
        alias intu="$common_intu_link"
    else
        echo "intu binary not found or not executable at $intu_cmd"
        return 1
    fi
}

# Setup clipboard functionality for the current platform
setup_clipboard() {
    local platform_cmd=$1
    local clip_cmd

    case "$platform_cmd" in
        OSX-*)
            clip_cmd="pbcopy"
            ;;
        LINUX-*)
            if command -v xclip &>/dev/null; then
                clip_cmd="xclip -selection clipboard"
            elif command -v xsel &>/dev/null; then
                clip_cmd="xsel --clipboard --input"
            elif command -v clip.exe &>/dev/null; then
                # This is for Windows Subsystem for Linux (WSL)
                clip_cmd="clip.exe"
            else
                echo "No suitable clipboard command found. Please install xclip or xsel."
                return 1
            fi
            ;;
        CYGWIN-*)
            clip_cmd="clip.exe"
            ;;
        *)
            echo "Unsupported operating system for clipboard operations."
            return 1
            ;;
    esac

    if [[ -n "$clip_cmd" ]]; then
        alias clip="$clip_cmd"
    else
        echo "Failed to set clipboard alias."
        return 1
    fi
}

# Initialize platform-specific settings
init_platform() {
    # Export platform information
    export SHELL_PLATFORM=$(detect_shell_platform)
    export SHELL_ARCHITECTURE=$(detect_architecture)

    # Set up platform-specific configurations
    setup_platform_specific

    # Set up platform-specific executables
    setup_platform_executables
}

# Call initialization when the file is sourced
init_platform
