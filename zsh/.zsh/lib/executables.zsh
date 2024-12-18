#!/bin/zsh

# Setup FZF for the current platform
setup_fzf() {
    local fzf_cmd
    local common_fzf_link="$HOME/bin/fzf"

    if is_osx; then
        if is_arm; then
            fzf_cmd="$HOME/bin/fzf-darwin-arm64"
        else
            fzf_cmd="$HOME/bin/fzf-darwin-amd64"
        fi
    elif is_linux; then
        if is_arm; then
            fzf_cmd="$HOME/bin/fzf-linux-arm64"
        else
            fzf_cmd="$HOME/bin/fzf-linux-amd64"
        fi
    fi

    if [[ -n "$fzf_cmd" ]] && [[ -x "$fzf_cmd" ]]; then
        [[ ! -L "$common_fzf_link" ]] || [[ "$(readlink -- "$common_fzf_link")" != "$fzf_cmd" ]] && \
            ln -sf "$fzf_cmd" "$common_fzf_link"
    fi
}

# Setup Intu for the current platform
setup_intu() {
    local intu_cmd
    local common_intu_link="$HOME/bin/intu"

    if is_osx; then
        if is_arm; then
            intu_cmd="$HOME/bin/intu-darwin-arm64"
        else
            intu_cmd="$HOME/bin/intu-darwin-amd64"
        fi
    elif is_linux; then
        if is_arm; then
            intu_cmd="$HOME/bin/intu-linux-arm64"
        else
            intu_cmd="$HOME/bin/intu-linux-amd64"
        fi
    else
        echo "Unsupported platform for intu"
        return 1
    fi

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
    local clip_cmd

    if is_osx; then
        clip_cmd="pbcopy"
    elif is_linux; then
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
    elif is_windows; then
        clip_cmd="clip.exe"
    else
        echo "Unsupported operating system for clipboard operations."
        return 1
    fi

    if [[ -n "$clip_cmd" ]]; then
        alias clip="$clip_cmd"
    else
        echo "Failed to set clipboard alias."
        return 1
    fi
}

# Setup Homebrew if available
setup_homebrew() {
    if has_capability "homebrew"; then
        export HOMEBREW_NO_ANALYTICS=1
        local brew_prefix=$(/opt/homebrew/bin/brew --prefix)
        path=($brew_prefix/bin $brew_prefix/sbin $path)

        # Homebrew completions
        if [[ -r "$brew_prefix/share/zsh/site-functions/_brew" ]]; then
            fpath=($fpath $brew_prefix/share/zsh/site-functions)
            autoload -Uz compinit && compinit
        fi
    fi
}

# Main setup function for all platform-specific executables
setup_platform_executables() {
    # Setup common executables
    setup_fzf
    setup_intu
    setup_clipboard

    # Platform-specific setups
    if is_osx; then
        setup_homebrew

        # iTerm2 integration
        [[ -r "$HOME/.iterm2_shell_integration.zsh" ]] && source "$HOME/.iterm2_shell_integration.zsh"
    elif is_linux; then
        # Linux color support for ls and grep
        if [[ -x "/usr/bin/dircolors" ]]; then
            if [[ -r "$HOME/.dircolors" ]]; then
                eval "$(dircolors -b "$HOME/.dircolors")"
            else
                eval "$(dircolors -b)"
            fi
        fi
    fi
}

# Initialize all platform-specific executables when sourced
setup_platform_executables
