#!/usr/bin/env zsh
# ~/.zsh/lib/path_manager.zsh
# 
# Centralized PATH management system
# All PATH modifications should go through this module

# Path groups with priority (lower number = higher priority)
typeset -gA PATH_GROUPS
PATH_GROUPS=(
    [user]=1        # Personal scripts and binaries
    [language]=2    # Programming language paths (go, rust, python, etc)
    [tools]=3       # Development tools (homebrew, etc)
    [system]=4      # System overrides (/usr/local/bin)
    [default]=5     # OS defaults (preserved from path_helper)
)

# Storage for path entries
typeset -gA PATH_REGISTRY  # Full registry with metadata
typeset -ga PATH_ORDER     # Ordered list for building

# Initialize path management
path_init() {
    PATH_REGISTRY=()
    PATH_ORDER=()
}

# Add a path with group classification
# Usage: path_add [--group=GROUP | --user | --language | --tools | --system] PATH...
path_add() {
    local group="tools"  # sensible default
    local paths=()
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --user|--mine)
                group="user"
                shift
                ;;
            --lang|--language|--dev)
                group="language"
                shift
                ;;
            --tools|--apps)
                group="tools"
                shift
                ;;
            --system|--sys)
                group="system"
                shift
                ;;
            --default|--os)
                group="default"
                shift
                ;;
            --group=*)
                group="${1#--group=}"
                shift
                ;;
            --)
                shift
                paths+=("$@")
                break
                ;;
            -*)
                echo "path_add: unknown option: $1" >&2
                return 1
                ;;
            *)
                paths+=("$1")
                shift
                ;;
        esac
    done
    
    # Get priority for this group
    local priority="${PATH_GROUPS[$group]:-3}"
    
    # Add each path
    for p in "${paths[@]}"; do
        # Expand tilde and variables
        p="${~p}"
        
        # Create a unique key
        local key="${priority}_${group}_${p//\//_}"
        
        # Store in registry
        PATH_REGISTRY[$key]="$p:$group:$priority"
    done
}

# Build PATH from registry
path_build() {
    local -a new_path
    local -A seen
    
    # Sort keys by priority (numeric sort)
    local sorted_keys=(${(kon)PATH_REGISTRY})
    
    # Build path array
    for key in $sorted_keys; do
        local entry="${PATH_REGISTRY[$key]}"
        local p="${entry%%:*}"  # Extract path part
        
        # Expand path
        p="${~p}"
        
        # Add if exists and not seen
        if [[ -d "$p" ]] && [[ -z "${seen[$p]}" ]]; then
            new_path+=("$p")
            seen[$p]=1
        fi
    done
    
    # Export as PATH with deduplication
    typeset -U new_path
    export PATH="${(j.:.)new_path}"
}

# Add system paths that aren't already registered
path_add_system() {
    for p in ${(s.:.)PATH}; do
        # Check if this path is already registered
        local found=0
        for entry in ${PATH_REGISTRY}; do
            local registered_path="${entry%%:*}"
            [[ "$p" == "$registered_path" ]] && found=1 && break
        done
        
        # Add if not found
        if [[ $found -eq 0 ]]; then
            path_add --default "$p"
        fi
    done
}

# Show current PATH configuration
path_show() {
    echo "Current PATH entries by group:"
    echo "=============================="
    
    local last_group=""
    local index=1
    
    # Sort and display
    for key in ${(kon)PATH_REGISTRY}; do
        local entry="${PATH_REGISTRY[$key]}"
        local p="${entry%%:*}"
        local group="${${entry#*:}%%:*}"
        
        # Expand path for display
        p="${~p}"
        
        # Group header
        if [[ "$group" != "$last_group" ]]; then
            echo
            echo "[$group] (priority: ${PATH_GROUPS[$group]:-?})"
            last_group="$group"
        fi
        
        # Check existence
        local exists="[✓]"
        [[ ! -d "$p" ]] && exists="[✗]"
        
        printf "  %2d. %-50s %s\n" $index "$p" "$exists"
        ((index++))
    done
    
    echo
    echo "Current PATH:"
    echo "$PATH" | tr ':' '\n' | nl
}

# Find which PATH entry provides a command
path_which() {
    local cmd="$1"
    local full_path="$(command -v "$cmd" 2>/dev/null)"
    
    if [[ -z "$full_path" ]]; then
        echo "$cmd: command not found"
        return 1
    fi
    
    echo "$cmd is $full_path"
    
    # Find which PATH entry provides it
    local cmd_dir="$(dirname "$full_path")"
    local index=1
    
    for p in ${(s.:.)PATH}; do
        if [[ "$p" == "$cmd_dir" ]]; then
            echo "Provided by PATH entry #$index: $p"
            
            # Find in registry
            for key in ${(k)PATH_REGISTRY}; do
                local entry="${PATH_REGISTRY[$key]}"
                local reg_path="${entry%%:*}"
                reg_path="${~reg_path}"
                if [[ "$reg_path" == "$p" ]]; then
                    local group="${${entry#*:}%%:*}"
                    echo "Registered as group: $group"
                    break
                fi
            done
            break
        fi
        ((index++))
    done
}

# Clear a group or specific path
path_remove() {
    local target="$1"
    
    if [[ -n "${PATH_GROUPS[$target]}" ]]; then
        # Remove all paths in a group
        for key in ${(k)PATH_REGISTRY}; do
            local entry="${PATH_REGISTRY[$key]}"
            local group="${${entry#*:}%%:*}"
            [[ "$group" == "$target" ]] && unset "PATH_REGISTRY[$key]"
        done
        echo "Removed all paths from group: $target"
    else
        # Remove specific path
        for key in ${(k)PATH_REGISTRY}; do
            local entry="${PATH_REGISTRY[$key]}"
            local p="${entry%%:*}"
            p="${~p}"
            if [[ "$p" == "$target" ]]; then
                unset "PATH_REGISTRY[$key]"
                echo "Removed path: $target"
                break
            fi
        done
    fi
}

# Register a lazy-loaded path (won't fail if doesn't exist yet)
path_add_lazy() {
    local group="$1"
    shift
    
    # Add paths without checking existence
    for p in "$@"; do
        # Expand tilde and variables
        p="${~p}"
        
        # Get priority for this group
        local priority="${PATH_GROUPS[$group]:-3}"
        
        # Create a unique key
        local key="${priority}_${group}_${p//\//_}"
        
        # Store in registry with a lazy flag
        PATH_REGISTRY[$key]="$p:$group:$priority:lazy"
    done
}

# Convenience aliases
alias path_list='path_show'
alias path_find='path_which'