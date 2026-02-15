#!/bin/zsh

# Arrays of various tips for different tools and functionalities

# Expert-level ZSH hotkeys and expansions
zsh_hotkeys_tips=(
    "!!: Repeat last command"
    "!<num>: Repeat command by history event number"
    "!<prefix>: Repeat last command starting with <prefix>"
    "!?<string>?: Repeat last command containing <string>"
    "!:s/foo/bar/: Replace 'foo' with 'bar' in previous command"
    "!^: First argument of last command, !$: Last argument of last command"
    "Alt+. (Esc .): Insert last word of previous command line"
    "Ctrl+R: Reverse incremental search in history"
    "Ctrl+W: Delete previous word"
    "Ctrl+U: Delete to start of line"
    "Ctrl+K: Delete to end of line"
    "Ctrl+Y: Yank last killed text"
    "Alt+B/F: Move backward/forward one word in command line"
    "Ctrl+X Ctrl+E: Edit current command line in \$EDITOR"
    "^foo^bar: Inline substitution in the last command"
)

# Neovim tips
nvim_tips=(
    "Use ,tt to open a new tab, ,tc to close it"
    "Use ,tn for next tab, ,tp for previous tab"
    "Navigate between windows with Ctrl+h/j/k/l"
    "Clear search highlighting with ,<Space>"
    ",e toggles the file explorer (Neo-tree)"
    ",ff opens fuzzy file finder (Telescope)"
    ",fg searches for text in files (live grep)"
    ",fb shows open buffers in Telescope"
    ",fh searches help tags"
    ",db toggles debug breakpoint"
    ",dc continues debugging"
    ",ds steps over in debugger"
    ",di steps into in debugger"
    ",do steps out in debugger"
    ",du opens debug UI"
    ",so opens symbols outline"
    "gd jumps to definition"
    "K shows hover documentation"
    ",rn renames symbol under cursor"
    ",ca shows code actions"
    "gr shows references"
    ",f formats current buffer"
    "Use Ctrl-\ to toggle floating terminal"
    "Tab accepts Copilot suggestion"
    "Alt-] and Alt-[ cycle through Copilot suggestions"
    "Alt-w accepts word from Copilot"
    "Alt-l accepts line from Copilot"
    "Ctrl-] dismisses Copilot suggestion"
    "Shift-h and Shift-l navigate between tabs"
)

# Vim movement tips
vim_movement_tips=(
    "% jumps between matching brackets/braces/parentheses"
    "[[ and ]] jump between class/function definitions in Python"
    "[m and ]m jump to start/end of next method in many languages"
    "va{ selects everything inside and including {} (works great for functions)"
    "vi{ selects everything inside {} (without the braces)"
    "vib selects inside blocks (similar to vi{ but works with (), [], {})"
    "]p and [p jump between paragraphs"
    "gd jumps to local definition of word under cursor"
    "* and # search for word under cursor forward/backward"
    "vi\" or va\" selects inside or around quotes"
    "vip selects inside paragraph"
    "viw selects inside word"
    "vat selects around XML/HTML tags"
    "vit selects inside XML/HTML tags"
    "f{char} jumps to next occurrence of {char} in line"
    "t{char} jumps until next occurrence of {char} in line"
    "; and , repeat last f, t, F, or T movement"
    "zf% creates a fold from cursor to matching bracket"
    "V% visually selects from cursor to matching bracket"
    "d% deletes from cursor to matching bracket"
    "c% changes text from cursor to matching bracket"
    "daB deletes a {} block (including braces)"
    "diB deletes inside {} block"
    "da) deletes a () block (including parentheses)"
    "di) deletes inside () block"
)

# Telescope tips
telescope_tips=(
    "Use <leader>ff to find files quickly in your current directory"
    "Use <leader>fg to perform live grep across all files - great for finding specific code snippets"
    "Use <leader>fb to search through open buffers"
    "Use <leader>fh to search through help tags - perfect for finding vim/neovim documentation"
    "Press <C-u>/<C-d> in telescope to scroll up/down in the preview window"
    "Press <C-x> to split horizontally with selected file, <C-v> for vertical split"
    "Press <Tab> to select multiple files in telescope, then <C-x> or <C-v> to open all of them"
    "Use <C-q> to send telescope results to quickfix list"
    "Press ? in normal mode or <C-/> in insert mode to see all telescope mappings"
    "Use <C-n>/<C-p> or <Down>/<Up> to navigate through results"
    "Type :Telescope followed by <Tab> to see all available telescope commands"
    "Use <C-r><C-w> in telescope prompt to insert the word under cursor"
    "Press <Esc> to exit telescope or switch to normal mode for vim-style navigation"
    "Use <CR> (Enter) to select and open a file in telescope"
    "Combine with git: try :Telescope git_files to search only tracked files"
)

# Combine all tips into one array
all_tips=(
    "${vim_movement_tips[@]}"
    "${nvim_tips[@]}"
    "${zsh_hotkeys_tips[@]}"
    "${telescope_tips[@]}"
)

# Function to show a random daily tip
show_daily_tip() {
    local tip_index=$((RANDOM % ${#all_tips[@]}))
    local tip="${all_tips[$tip_index]}"

    # Display the tip using gum if available, otherwise regular echo
    if command -v gum >/dev/null 2>&1; then
        gum style \
            --border normal \
            --margin "1" \
            --padding "1" \
            --width 70 \
            "$(gum style --foreground 212 '💡 Daily Tip:')" \
            "$(gum style --foreground 99 "$tip")"
    else
        echo "💡 Daily Tip:"
        echo "$tip"
    fi
}

# Function to display ZSH hotkeys help
zsh_hotkeys_help() {
    cat <<EOF
Expert-level ZSH history expansions and hotkeys:
  !!          : Repeat last command
  !<num>      : Repeat command by history event number
  !<prefix>   : Repeat last command starting with <prefix>
  !?<string>? : Repeat last command containing <string>
  !:s/foo/bar/: Replace 'foo' with 'bar' in previous command
  !^          : Insert first argument of last command
  !$          : Insert last argument of last command
  Alt+.       : Insert last word of previous command line
  Ctrl+R      : Reverse incremental history search
  Ctrl+W      : Delete previous word
  Ctrl+U      : Delete to start of line
  Ctrl+K      : Delete to end of line
  Ctrl+Y      : Yank last killed text
  Alt+B/F     : Move backward/forward one word
  Ctrl+X Ctrl+E: Edit command line in \$EDITOR
  ^foo^bar    : Quick inline substitution in last command
EOF
}

# Function to show tips for a specific tool
show_tool_tips() {
    local tool=$1
    case "$tool" in
        "vim")
            printf "%s\n" "${vim_movement_tips[@]}"
            ;;
        "nvim")
            printf "%s\n" "${nvim_tips[@]}"
            ;;
        "zsh")
            printf "%s\n" "${zsh_hotkeys_tips[@]}"
            ;;
        "telescope")
            printf "%s\n" "${telescope_tips[@]}"
            ;;
        *)
            echo "Available tools: vim, nvim, zsh, telescope"
            ;;
    esac
}
