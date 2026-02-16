#!/bin/zsh

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
        # Use static path to avoid slow brew call
        local brew_prefix="/opt/homebrew"

        # Homebrew completions (fpath and compinit already set up in .zshrc)
        if [[ -r "$brew_prefix/share/zsh/site-functions/_brew" ]]; then
            fpath=($fpath $brew_prefix/share/zsh/site-functions)
        fi
    fi
}

# Main setup function for all platform-specific executables
setup_platform_executables() {
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

# Don't auto-initialize - let .zshrc control the order
# setup_platform_executables
