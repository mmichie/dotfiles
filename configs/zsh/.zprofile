#!/bin/zsh
#
# .zprofile — sourced once per login shell, AFTER .zshenv and BEFORE .zshrc.
# Use it for setup that only makes sense for login sessions and needs to land
# before interactive setup begins.
#
# Right now that's just the macOS path_helper fix:
# /etc/zprofile invokes /usr/libexec/path_helper for login shells, which
# prepends /usr/bin etc. and re-orders PATH. Our .zshenv already set the
# order we wanted; re-apply it here, after path_helper has had its turn, so
# PATH is correct by the time .zshrc starts.
#
# Aliases, keybindings, completion, prompt → .zshrc (every interactive shell).
# Anything that should also fire for scripts/non-interactive shells → .zshenv.

[[ "$OSTYPE" == darwin* ]] && typeset -f setup_path >/dev/null && setup_path
