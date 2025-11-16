#!/bin/zsh

# Automatic emoji titles for tmux windows based on running commands
# Requires tmux to be running

# Map of commands to emojis (must be global)
typeset -gA TMUX_EMOJI_MAP
TMUX_EMOJI_MAP=(
    # Containers/Deployment
    docker     "🐳"
    kubectl    "☸️"
    k9s        "☸️"
    helm       "⎈"

    # Editors
    vim        "📝"
    nvim       "📝"
    vi         "📝"
    code       "💻"

    # Languages/REPLs
    python     "🐍"
    python3    "🐍"
    ipython    "🐍"
    node       "⬢"
    irb        "💎"
    ruby       "💎"
    cargo      "🦀"
    rust       "🦀"

    # Development Tools
    make       "🔨"
    cmake      "🔨"
    pytest     "🧪"
    jest       "🧪"
    test       "🧪"
    npm        "📦"
    yarn       "📦"
    pnpm       "📦"
    psql       "🗄️"
    mysql      "🗄️"
    sqlite3    "🗄️"
    mongo      "🗄️"
    redis-cli  "🗄️"
    htop       "📊"
    top        "📊"
    btop       "📊"
    tail       "👀"
    less       "📖"
    man        "📖"

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

# Clear emoji title when command completes (unless it's a long-running one)
_tmux_emoji_precmd() {
    [[ -z "$TMUX" ]] && return

    # Check if current pane has custom title set by preexec
    local custom_title=$(tmux show-options -p -v @custom_title 2>/dev/null)

    # Only clear if it's NOT ssh or claude (they manage their own cleanup)
    if [[ -n "$custom_title" && "$custom_title" != 🔐* && "$custom_title" != 🤖* ]]; then
        tmux set-option -p @custom_title ""
        # Update title based on current directory
        local cmd=$(tmux display-message -p "#{pane_current_command}")
        if [[ "$cmd" == "zsh" ]] || [[ "$cmd" == "bash" ]]; then
            tmux rename-window "$(tmux display-message -p "#{b:pane_current_path}")"
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
