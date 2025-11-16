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

    # Already handled by wrappers
    ssh        "🔐"
    claude     "🤖"
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
    local dir_name=$(basename "$PWD")
    local emoji="📁"

    # Home directory gets special treatment
    if [[ "$PWD" == "$HOME" ]]; then
        dir_name="~"
        emoji="🏠"
    else
        # Check if we're in a git repository
        if git rev-parse --git-dir &>/dev/null; then
            # Check if there are uncommitted changes
            if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
                emoji="📦"  # Dirty git repo
            else
                emoji="✓"  # Clean git repo
            fi
        fi
    fi

    # Add warning prefix if running as root
    local prefix=""
    local is_root=$(tmux show-options -p -v @is_root 2>/dev/null)
    if [[ "$is_root" == "1" ]]; then
        prefix="⚠️ "
    fi

    echo "${prefix}${emoji} ${dir_name}"
}

# Clear emoji title when command completes (unless it's a long-running one)
_tmux_emoji_precmd() {
    [[ -z "$TMUX" ]] && return

    # Check if current pane has custom title set by preexec
    local custom_title=$(tmux show-options -p -v @custom_title 2>/dev/null)

    # Only clear if it's NOT ssh/claude/root (they manage their own cleanup)
    if [[ -n "$custom_title" && "$custom_title" != 🔐* && "$custom_title" != 🤖* && "$custom_title" != ⚠️* ]]; then
        tmux set-option -p @custom_title ""
    fi

    # If no custom title from ssh/claude/root, set smart directory title
    if [[ -z "$custom_title" ]] || [[ "$custom_title" != 🔐* && "$custom_title" != 🤖* && "$custom_title" != ⚠️* ]]; then
        local cmd=$(tmux display-message -p "#{pane_current_command}")
        if [[ "$cmd" == "zsh" ]] || [[ "$cmd" == "bash" ]]; then
            local smart_title=$(_tmux_emoji_get_dir_title)
            # Store in pane variable so hook can use it when switching panes
            tmux set-option -p @dir_title "$smart_title"
            tmux rename-window "$smart_title"
        else
            tmux rename-window "$cmd"
        fi
    fi
}

# Register hooks - append directly to avoid autoload issues
typeset -ga preexec_functions
typeset -ga precmd_functions
preexec_functions+=(_tmux_emoji_preexec)
precmd_functions+=(_tmux_emoji_precmd)
