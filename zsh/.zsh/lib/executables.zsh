#!/bin/zsh

# Setup FZF for the current platform
setup_fzf() {
    setup_platform_binary "fzf" && \
    export FZF_DEFAULT_OPTS="--height 40% --border"
}


# Setup Intu for the current platform
setup_intu() {
    setup_platform_binary "intu" && \
    alias intu="$HOME/bin/intu"
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
        
        # Only add brew paths if they're not already in the path
        local brew_bin="$brew_prefix/bin"
        local brew_sbin="$brew_prefix/sbin"
        
        # Check if brew paths are already in the path array
        local found_bin=0
        local found_sbin=0
        local p
        for p in $path; do
            [[ "$p" == "$brew_bin" ]] && found_bin=1
            [[ "$p" == "$brew_sbin" ]] && found_sbin=1
        done
        
        # Add only if not found
        if [[ $found_bin -eq 0 || $found_sbin -eq 0 ]]; then
            # Prepend brew paths if not already present
            if [[ $found_bin -eq 0 && $found_sbin -eq 0 ]]; then
                path=($brew_bin $brew_sbin $path)
            elif [[ $found_bin -eq 0 ]]; then
                path=($brew_bin $path)
            elif [[ $found_sbin -eq 0 ]]; then
                path=($brew_sbin $path)
            fi
        fi

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

# Don't auto-initialize - let .zshrc control the order
# setup_platform_executables
