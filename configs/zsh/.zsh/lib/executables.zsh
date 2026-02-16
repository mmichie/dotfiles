#!/bin/zsh

# Setup clipboard alias
setup_clipboard() {
    if is_osx; then
        alias clip="pbcopy"
    elif is_linux; then
        if command -v xclip &>/dev/null; then
            alias clip="xclip -selection clipboard"
        elif command -v xsel &>/dev/null; then
            alias clip="xsel --clipboard --input"
        fi
    fi
}

# Main setup function for platform-specific executables
setup_platform_executables() {
    setup_clipboard

    if is_osx && has_capability "homebrew"; then
        export HOMEBREW_NO_ANALYTICS=1
    fi
}
