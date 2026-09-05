#!/bin/zsh

# Banner + tip, at most once per BANNER_INTERVAL seconds (default hourly)
# across all shells, tracked by a stamp file. The old `-o login` gate fired
# on every macOS terminal tab and tmux pane (~90ms each); the stamp makes it
# genuinely "first shell in a while". INFLUX_SHOWN=1 suppresses entirely
# (tests, scripted shells). Numbered last: notify_shell_status comes from
# 60-prompt.zsh, and `tips` relies on the autoload registrations .zshrc
# does before the module loop.
# -t 1: only when stdout is a terminal. The banner is terminal graphics and
# the tip is for a human at a prompt; an interactive shell with captured
# stdout (an editor plugin's `zsh -i`, a `zsh -ic` probe) would otherwise
# get the bytes in its own output (1.4MB of kitty-graphics escapes,
# observed) and, because the stamp is written before display, consume the
# hourly slot the next real terminal was owed. Checked ahead of the stamp
# glob for that reason.
if [[ -z "$INFLUX_SHOWN" && -t 1 ]] && command -v gum &>/dev/null; then
    _banner_recent=("$SHELL_CACHE_DIR/banner-stamp"(N.ms-${BANNER_INTERVAL:-3600}))
    if (( ${#_banner_recent} == 0 )); then
        # Not exported: this only has to suppress a re-source in THIS shell.
        # An exported flag lands in the tmux server environment and every
        # pane it spawns for the rest of the server's life; cross-shell rate
        # limiting is the stamp file's job.
        INFLUX_SHOWN=1
        # Stamp before displaying: rate-limits the attempt, so a banner
        # renderer dying mid-draw cannot re-trigger every shell.
        # `command true`, not `:` — any alias of `:` in an earlier-parsed
        # file (30-aliases.zsh once had `alias :="cd .."`, ~/.zshrc.local
        # could add one) expands into this line at parse time; that bug
        # made the hourly banner shell cd to its parent directory.
        command true >| "$SHELL_CACHE_DIR/banner-stamp"
        notify_shell_status
        tips
    fi
    unset _banner_recent
fi
