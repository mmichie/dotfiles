#!/bin/zsh

# Constants by convention, not readonly: `source ~/.zshrc` is the reload
# path, and readonly would error on every re-source.
typeset -g AGENT_SOCKET="$HOME/.ssh/.ssh-agent-socket"
typeset -g AGENT_INFO="$HOME/.ssh/.ssh-agent-info"
typeset -g ONEPASSWORD_SOCKET_MACOS="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
typeset -g ONEPASSWORD_SOCKET_LINUX="$HOME/.1password/agent.sock"
# Stable indirection for a forwarded agent. A forwarded SSH_AUTH_SOCK is
# per-login and ephemeral, so a tmux pane that outlives the login that spawned
# it is left pointing at a dead socket after re-attach. ~/.ssh/rc repoints this
# symlink at each login's socket (see .ssh/rc); shells just consume it, so a
# pane follows the newest agent without re-exporting SSH_AUTH_SOCK by hand.
typeset -g AGENT_STABLE_LINK="$HOME/.ssh/ssh_auth_sock"

# Export SSH_AUTH_SOCK pointing at a 1Password agent if one is running.
# Returns 0 on hit, 1 on miss.
_use_1password_socket_if_present() {
    local sock
    for sock in "$ONEPASSWORD_SOCKET_MACOS" "$ONEPASSWORD_SOCKET_LINUX"; do
        if [[ -S "$sock" ]]; then
            export SSH_AUTH_SOCK="$sock"
            return 0
        fi
    done
    return 1
}

# Pick an SSH agent in preference order:
#   1. 1Password (macOS or Linux)
#   2. Forwarded / externally-set SSH_AUTH_SOCK (ssh -A, systemd user socket)
#   3. Traditional ssh-agent (Linux boxes without 1Password)
handle_ssh_agent() {
    _use_1password_socket_if_present && return 0

    # Forwarded agent (ssh -A). Prefer the stable link (repointed at login by
    # ~/.ssh/rc) so a tmux pane that outlived its login follows the newest
    # forwarded socket. Cheap -S only -- no agent round-trip at shell startup.
    if [[ -S "$AGENT_STABLE_LINK" ]]; then
        export SSH_AUTH_SOCK="$AGENT_STABLE_LINK"
        return 0
    fi

    if [[ -n "$SSH_AUTH_SOCK" ]] && [[ -S "$SSH_AUTH_SOCK" ]]; then
        return 0
    fi

    if [[ -s "$AGENT_INFO" ]]; then
        source "$AGENT_INFO"
    fi

    # ssh-add -l exit codes: 0 = agent has keys, 1 = agent alive but
    # keyless, 2 = agent unreachable. Restarting on 1 leaked a fresh agent
    # per shell on machines with no id_* keys to add.
    ssh-add -l &>/dev/null
    if (( $? == 2 )) || [[ ! -S "$AGENT_SOCKET" ]]; then
        restart_ssh_agent
    fi
}

restart_ssh_agent() {
    mkdir -p "$(dirname "$AGENT_SOCKET")" "$(dirname "$AGENT_INFO")"
    chmod 700 "$(dirname "$AGENT_SOCKET")" "$(dirname "$AGENT_INFO")"

    # -e/-L, not -S: any stale file at the socket path (plain file, dead
    # symlink) makes ssh-agent's bind fail after AGENT_INFO was truncated.
    [[ -e "$AGENT_SOCKET" || -L "$AGENT_SOCKET" ]] && rm -f "$AGENT_SOCKET"

    echo "Starting new SSH agent..."
    ssh-agent -a "$AGENT_SOCKET" > "$AGENT_INFO"
    source "$AGENT_INFO"

    add_ssh_keys
}

add_ssh_keys() {
    local key_count=0 key fingerprint
    for key in "$HOME/.ssh"/id_*(N); do
        [[ -f "$key" && "$key" != *.pub ]] || continue
        # An empty fingerprint (unreadable key, encrypted key with no .pub
        # sidecar) would make the grep below match everything and silently
        # skip the key forever.
        fingerprint=$(ssh-keygen -lf "$key" 2>/dev/null | awk '{print $2}')
        if [[ -z "$fingerprint" ]]; then
            echo "Skipping $key: cannot compute fingerprint" >&2
            continue
        fi
        if ! ssh-add -l | grep -qF "$fingerprint"; then
            ssh-add "$key" && ((key_count++))
        fi
    done
    echo "Added $key_count SSH key(s) to agent"
}

init_ssh() {
    # Fast path: 1Password agent present → skip agent-dir setup entirely
    _use_1password_socket_if_present && return

    # No 1Password — fall back to managed ssh-agent. Use zsh :h modifier
    # instead of $(dirname ...) subshells.
    mkdir -p "${AGENT_SOCKET:h}" "${AGENT_INFO:h}"
    chmod 700 "${AGENT_SOCKET:h}" "${AGENT_INFO:h}"
    handle_ssh_agent
}

init_ssh

# Parse the ssh destination out of an argv: skip flags (and the values of
# flags that take one), stop at the first bare word. Returns via $REPLY.
# The old "last arg" parse titled the window after the remote command for
# `ssh host uptime`.
_ssh_title_host() {
    local -a argv=("$@")
    local -i i=1 consumed
    local a host="" rest c
    while (( i <= ${#argv} )); do
        a="$argv[i]"
        case "$a" in
            --) host="${argv[i+1]:-}"; break ;;
            -*)
                # Short-flag cluster: booleans may precede one valued flag,
                # whose value is the rest of the cluster or, when it ends the
                # cluster, the next argument (-vp 2222, -4p2222, -vi key).
                rest="${a[2,-1]}"; consumed=1
                while [[ -n "$rest" ]]; do
                    c="${rest[1]}"; rest="${rest[2,-1]}"
                    if [[ "$c" == [BbcDEeFIiJLlmOoPpQRSWw] ]]; then
                        [[ -z "$rest" ]] && consumed=2
                        break
                    fi
                done
                (( i += consumed )); continue ;;
            *) host="$a"; break ;;
        esac
    done
    host="${host#ssh://}"
    host="${host#*@}"
    host="${host%%:*}"
    host="${host%%/*}"
    REPLY="${host:-ssh}"
}

# Undo terminal modes a remote session that died mid-app (broken pipe out
# of tmux/vim) can never restore itself: kitty keyboard protocol (pop),
# mouse tracking + SGR/urxvt encodings, focus reporting, bracketed paste,
# hidden cursor. Left enabled, every mouse move types \e[<35;x;yM garbage
# into the next prompt.
_ssh_reset_modes() {
    printf '\e[<u\e[?1000l\e[?1001l\e[?1002l\e[?1003l\e[?1004l\e[?1005l\e[?1006l\e[?1015l\e[?2004l\e[?25h'
}

# Hosts whose nix config ships ghostty's terminfo (homelab repo:
# environment.enableAllTerminfo) — ssh sends them the real TERM, keeping
# what xterm-256color lacks (undercurl, synchronized output).
typeset -ga GHOSTTY_TERM_HOSTS=(wintermute homelab)

# SSH wrapper to auto-rename tmux windows to hostname
unalias ssh 2>/dev/null
ssh() {
    local REPLY
    _ssh_title_host "$@"
    # Remotes rarely carry ghostty's terminfo, and an unknown TERM breaks
    # the login (NixOS set-environment errors on its TERM reload). Outside
    # the allowlist above, send the plain entry instead — the translation
    # ghostty's ssh-env integration would do if it could load here (it
    # can't: windows run tmux-attach-or-new, not a shell ghostty detects,
    # and this function would shadow its ssh wrapper anyway).
    local term="$TERM"
    if [[ "$term" == xterm-ghostty ]] && (( ! ${GHOSTTY_TERM_HOSTS[(Ie)$REPLY]} )); then
        term=xterm-256color
    fi
    TERM="$term" _tmux_title_wrap "🔐 $REPLY" command ssh "$@"
    local exit_code=$?
    # Repair only a live tty — never spill escapes into a pipe or file.
    [[ -t 1 ]] && _ssh_reset_modes
    return $exit_code
}

# Sudo wrapper to warn about persistent root shells
unalias sudo 2>/dev/null
# Resolve the real sudo binary once — NixOS needs /run/wrappers/bin/sudo (setuid)
_sudo_bin="${commands[sudo]:-sudo}"
[[ -x /run/wrappers/bin/sudo ]] && _sudo_bin=/run/wrappers/bin/sudo
sudo() {
    local is_interactive=0 arg
    local -a sudo_args=("$@")
    local -i i
    # Valued options consume the next argument (or the rest of their
    # cluster); their values must not be mistaken for the `su` command or
    # for -i/-s. Short set from sudo(8): -a type, -C num, -D dir, -g group,
    # -h host, -p prompt, -R dir, -r role, -t type, -T timeout, -U user,
    # -u user.
    local -a valued_long=(--auth-type --close-from --chdir --chroot --group --host \
                          --prompt --role --type --command-timeout --other-user --user)
    local rest c
    for (( i = 1; i <= ${#sudo_args}; i++ )); do
        arg="${sudo_args[i]}"
        case "$arg" in
            --login|--shell) is_interactive=1; break ;;
            --*) (( ${valued_long[(Ie)$arg]} )) && (( i++ )) ;;
            -?*)
                # Short cluster: booleans may precede -i/-s or one valued
                # option (-iu root, -Eu root -i, -Es). A valued option ends
                # the cluster; its value is the rest of it or the next arg.
                rest="${arg[2,-1]}"
                while [[ -n "$rest" ]]; do
                    c="${rest[1]}"; rest="${rest[2,-1]}"
                    case "$c" in
                        i|s) is_interactive=1; break 2 ;;
                        [aCDghpRrtTUu]) [[ -z "$rest" ]] && (( i++ )); break ;;
                    esac
                done
                ;;
            *)  # first bare word is the command; `su` without args is interactive
                [[ "$arg" == "su" ]] && is_interactive=1
                break ;;
        esac
    done

    if [[ -z "$TMUX" || $is_interactive -eq 0 ]]; then
        $_sudo_bin "$@"
        return
    fi

    # Mark pane as root-owned — _tmux_title_pop clears it during wrap exit.
    tmux set-option -t "$(tmux display-message -p '#{pane_id}')" -p @is_root "1"
    _tmux_title_wrap "⚠️ ROOT" "$_sudo_bin" "$@"
}
