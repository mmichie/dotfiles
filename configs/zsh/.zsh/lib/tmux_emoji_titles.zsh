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

# Extract the base command from a command line
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

    echo "$cmd"
}

# Set emoji title when command starts
_tmux_emoji_preexec() {
    [[ -z "$TMUX" ]] && return

    local priority_title=$(tmux show-options -w -v @priority_title 2>/dev/null)
    [[ -n "$priority_title" ]] && return

    local base_cmd=$(_tmux_emoji_get_command "$1")
    local emoji="${TMUX_EMOJI_MAP[$base_cmd]}"

    if [[ -n "$emoji" && "$base_cmd" != "ssh" && "$base_cmd" != "claude" ]]; then
        tmux set-option -p @custom_title "$emoji $base_cmd" \; rename-window "$emoji $base_cmd"
    fi
}

# Register preexec hook (precmd dir title is now handled by plx prompt)
typeset -ga preexec_functions
preexec_functions+=(_tmux_emoji_preexec)
