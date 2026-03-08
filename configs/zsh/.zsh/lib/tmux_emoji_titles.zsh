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

    # Check if window has a priority title (window-level) - if so, don't override
    local priority_title=$(tmux show-options -w -v @priority_title 2>/dev/null)
    if [[ -n "$priority_title" ]]; then
        return
    fi

    local full_cmd="$1"
    local base_cmd=$(_tmux_emoji_get_command "$full_cmd")

    # Check if we have an emoji for this command
    local emoji="${TMUX_EMOJI_MAP[$base_cmd]}"

    if [[ -n "$emoji" ]]; then
        # Don't override ssh/claude wrappers which set their own titles
        if [[ "$base_cmd" != "ssh" && "$base_cmd" != "claude" ]]; then
            local title="$emoji $base_cmd"
            tmux set-option -p @custom_title "$title"
            tmux rename-window "$title"
        fi
    fi
}

# Get smart directory title with context-aware emoji
_tmux_emoji_get_dir_title() {
    local title
    title=$(plx tmux-title 2>/dev/null)
    if [[ -z "$title" ]]; then
        # Fallback if binary fails
        title="📁 $(basename "$PWD")"
    fi

    # Add warning prefix if running as root
    local is_root=$(tmux show-options -p -v @is_root 2>/dev/null)
    if [[ "$is_root" == "1" ]]; then
        title="⚠️ ${title}"
    fi

    echo "$title"
}

# Clear emoji title when command completes (unless it's a long-running one)
_tmux_emoji_precmd() {
    [[ -z "$TMUX" ]] && return

    # Check if window has a priority title (window-level) - if so, don't touch anything
    local priority_title=$(tmux show-options -w -v @priority_title 2>/dev/null)
    if [[ -n "$priority_title" ]]; then
        # Window has priority title (ssh/claude/root), don't update anything
        return
    fi

    # Check if current pane has custom title set by preexec
    local custom_title=$(tmux show-options -p -v @custom_title 2>/dev/null)

    # If we have a custom title from ssh/claude/root, don't touch anything
    if [[ -n "$custom_title" && ( "$custom_title" == 🔐* || "$custom_title" == ✨* || "$custom_title" == ⚠️* ) ]]; then
        # Keep the custom title, don't update anything
        return
    fi

    # Only clear if it's NOT ssh/claude/root (they manage their own cleanup)
    if [[ -n "$custom_title" ]]; then
        tmux set-option -p @custom_title ""
        # Re-enable automatic-rename when clearing custom title
        tmux set-window-option automatic-rename on
    fi

    # Set smart directory title
    # Note: precmd only runs when the shell is active, so we always set the
    # directory title here regardless of what pane_current_command reports
    # (tmux may have a stale value from the just-finished command)
    local smart_title=$(_tmux_emoji_get_dir_title)
    # Store in pane variable so hook can use it when switching panes
    tmux set-option -p @dir_title "$smart_title"
    tmux rename-window "$smart_title"
    # Re-enable automatic-rename so long-running commands update the title
    tmux set-window-option automatic-rename on
}

# Register hooks - append directly to avoid autoload issues
typeset -ga preexec_functions
typeset -ga precmd_functions
preexec_functions+=(_tmux_emoji_preexec)
precmd_functions+=(_tmux_emoji_precmd)
