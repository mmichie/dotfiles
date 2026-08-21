#!/bin/zsh

# Automatic emoji titles for tmux windows based on running commands
# Requires tmux to be running

# Map of commands to emojis (must be global)
typeset -gA TMUX_EMOJI_MAP
TMUX_EMOJI_MAP=(
    # Containers/Deployment
    docker          "🐳"
    docker-compose  "🐙"
    kubectl         "☸️"
    k9s             "☸️"
    helm            "⎈"
    minikube        "🎡"

    # Editors
    vim        "📝"
    nvim       "📝"
    vi         "📝"
    code       "💻"
    nano       "📄"
    micro      "📄"
    emacs      "📄"

    # Languages/REPLs
    python     "🐍"
    python3    "🐍"
    ipython    "🐍"
    node       "⬢"
    irb        "💎"
    ruby       "💎"
    cargo      "🦀"
    rust       "🦀"
    go         "🐹"
    java       "☕"
    javac      "☕"
    tsc        "🟦"

    # Development Tools
    make       "🔨"
    cmake      "🔨"
    pytest     "🧪"
    jest       "🧪"
    test       "🧪"
    npm        "📦"
    yarn       "📦"
    pnpm       "📦"
    pip        "📦"
    gem        "📦"
    composer   "📦"
    brew       "🍺"
    gradle     "🏗️"
    maven      "🏗️"
    bazel      "🏗️"

    # Databases
    psql       "🗄️"
    mysql      "🗄️"
    sqlite3    "🗄️"
    mongo      "🗄️"
    mongosh    "🗄️"
    redis-cli  "🗄️"

    # Monitoring/System
    htop       "📊"
    top        "📊"
    btop       "📊"
    tail       "👀"
    less       "📖"
    man        "📖"
    journalctl "📋"
    dmesg      "📋"

    # Debugging
    strace     "🔬"
    ltrace     "🔬"
    gdb        "🐛"
    lldb       "🐛"
    pdb        "🐛"

    # Network/Transfer
    curl       "🌐"
    wget       "🌐"
    ping       "📡"
    netstat    "📡"
    ss         "📡"
    lsof       "📡"
    rsync      "📤"
    scp        "📤"

    # Text Processing
    grep       "🔍"
    rg         "🔍"
    ag         "🔍"
    sed        "✂️"
    awk        "✂️"
    sort       "🔀"
    uniq       "🔀"
    jq         "🔀"

    # Cloud CLIs
    aws        "☁️"
    gcloud     "☁️"
    az         "☁️"
    terraform  "🌊"
    terragrunt "🌊"

    # Misc
    sleep      "💤"

    # Already handled by wrappers
    ssh        "🔐"
    claude     "✨"
)

# Extract the base command from a command line. Returns via $REPLY —
# this runs in preexec on every command typed, and a $(...) capture at the
# call site would cost a subshell fork each time.
_tmux_emoji_get_command() {
    local cmd="$1"
    local first tok fallback=""
    local -i had_wrapper=0

    # Wrappers stack and interleave with their own flags: `sudo -E time
    # make`, `nice -n 5 cargo`. One hard-coded strip per wrapper only
    # handled a single leading prefix and left the wrapper's flags as the
    # "command". One loop instead, alternating wrappers and their flag
    # tokens. Valued wrapper options consume the NEXT token too, keyed by
    # the wrapper just stripped (sudo's -n is boolean, nice's is valued —
    # they must not be conflated). Joined forms (-uroot) are not split.
    local -a wrappers=(sudo time nice nohup)
    local -A valued_flags=(
        sudo  '-u -g -h -p -t -T -C -D -R -U -a -c -r --user --group --host --prompt --command-timeout --chdir --role --type --close-from --chroot --other-user --auth-type --login-class'
        nice  '-n --adjustment'
        time  '-f -o --format --output'
        nohup ''
    )
    local last_wrapper=""
    while true; do
        first="${cmd%% *}"
        if (( ${wrappers[(Ie)$first]} )); then
            had_wrapper=1
            last_wrapper="$first"
            # Loop must terminate: a lone wrapper word (`sudo` alone)
            # strips to empty; $fallback restores it below.
            fallback="$first"
            [[ "$cmd" == "$first" ]] && cmd="" && break
            # Strip the first word + ALL following whitespace (not just one
            # space): `sudo  make` with 2+ spaces left the remainder starting
            # with spaces, and ${cmd%% *} below returned empty (dropping the
            # emoji title for any command typed with extra whitespace).
            cmd="${cmd[$(( ${#first} + 1 )),-1]}"
            # Trim leading spaces without EXTENDED_GLOB (the test sources
            # this module standalone, before 05-options sets it).
            while [[ "$cmd" == " "* ]]; do cmd="${cmd# }"; done
            continue
        fi
        if (( had_wrapper )) && [[ "$first" == -* ]]; then
            [[ "$cmd" == "$first" ]] && cmd="" && break
            cmd="${cmd[$(( ${#first} + 1 )),-1]}"
            while [[ "$cmd" == " "* ]]; do cmd="${cmd# }"; done
            # Valued option: drop its argument token as well.
            if [[ -n "${valued_flags[$last_wrapper]}" \
                && " ${valued_flags[$last_wrapper]} " == *" $first "* \
                && -n "$cmd" ]]; then
                tok="${cmd%% *}"
                [[ "$cmd" == "$tok" ]] && cmd="" && break
                cmd="${cmd[$(( ${#tok} + 1 )),-1]}"
                while [[ "$cmd" == " "* ]]; do cmd="${cmd# }"; done
            fi
            continue
        fi
        break
    done

    # Everything stripped to empty (`sudo` alone): degrade to the wrapper.
    cmd="${cmd:-$fallback}"

    # Get first word (the actual command)
    cmd="${cmd%% *}"

    # Get basename (remove path)
    cmd="${cmd##*/}"

    # Plain assignment, not typeset -g: dynamic scoping must hit the
    # caller's `local REPLY`, which -g would bypass.
    REPLY="$cmd"
}

# Set emoji title when command starts. Hot path: zero forks unless an emoji
# actually needs setting — the pinned check is a shell variable maintained
# by _tmux_title_push/pop (was a tmux show-options subprocess per command).
_tmux_emoji_preexec() {
    [[ -z "$TMUX" ]] && return
    [[ -n "$_TMUX_TITLE_PINNED" ]] && return

    local REPLY
    _tmux_emoji_get_command "$1"
    local base_cmd="$REPLY"
    local emoji="${TMUX_EMOJI_MAP[$base_cmd]}"

    if [[ -n "$emoji" && "$base_cmd" != "ssh" && "$base_cmd" != "claude" ]]; then
        tmux set-option -p @custom_title "$emoji $base_cmd" \; rename-window "$emoji $base_cmd"
    fi
}

# Register preexec hook (precmd dir title is now handled by chevron prompt).
# Containment-guarded so re-sourcing .zshrc cannot register it twice.
typeset -ga preexec_functions
(( ${preexec_functions[(Ie)_tmux_emoji_preexec]} )) || preexec_functions+=(_tmux_emoji_preexec)
