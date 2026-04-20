#!/bin/zsh

# Main setup function for platform-specific executables.
# Clipboard setup now lives in clipboard.zsh (clipcopy/clippaste).
setup_platform_executables() {
    if is_osx && has_capability "homebrew"; then
        export HOMEBREW_NO_ANALYTICS=1
    fi

    if command -v dosbox-x &>/dev/null; then
        alias dosbox-x='dosbox-x -conf ~/.config/dosbox-x/dosbox-x.conf'
    fi
}
