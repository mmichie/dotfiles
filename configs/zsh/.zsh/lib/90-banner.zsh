#!/bin/zsh

# Banner + tip, at most once per BANNER_INTERVAL seconds (default hourly)
# across all shells, tracked by a stamp file. The old `-o login` gate fired
# on every macOS terminal tab and tmux pane (~90ms each); the stamp makes it
# genuinely "first shell in a while". INFLUX_SHOWN=1 suppresses entirely
# (tests, scripted shells). Numbered last: notify_shell_status comes from
# 60-prompt.zsh, and `tips` relies on the autoload registrations .zshrc
# does before the module loop.
if [[ -z "$INFLUX_SHOWN" ]] && command -v gum &>/dev/null; then
    _banner_recent=("$SHELL_CACHE_DIR/banner-stamp"(N.ms-${BANNER_INTERVAL:-3600}))
    if (( ${#_banner_recent} == 0 )); then
        export INFLUX_SHOWN=1
        # Stamp before displaying: rate-limits the attempt, so a banner
        # renderer dying mid-draw cannot re-trigger every shell.
        : >| "$SHELL_CACHE_DIR/banner-stamp"
        notify_shell_status
        tips
    fi
    unset _banner_recent
fi
