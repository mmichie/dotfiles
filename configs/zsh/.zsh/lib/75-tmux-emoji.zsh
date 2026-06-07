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

    # Strip leading sudo, time, nice, etc.
    cmd="${cmd#sudo }"
    cmd="${cmd#time }"
    cmd="${cmd#nice }"
    cmd="${cmd#nohup }"

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

# Register preexec hook (precmd dir title is now handled by chevron prompt)
typeset -ga preexec_functions
preexec_functions+=(_tmux_emoji_preexec)
