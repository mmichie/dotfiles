#!/bin/zsh

# Enhanced man pages with colors
man() {
    env \
        LESS_TERMCAP_md=$'\e[1;36m' \
        LESS_TERMCAP_me=$'\e[0m' \
        LESS_TERMCAP_se=$'\e[0m' \
        LESS_TERMCAP_so=$'\e[1;40;92m' \
        LESS_TERMCAP_ue=$'\e[0m' \
        LESS_TERMCAP_us=$'\e[1;32m' \
        man "$@"
}

# Check HTTP headers
http_headers() {
    /usr/bin/curl -I -L "$@"
}

# Create SSH tunnel
sshtunnel() {
    if [[ $# -ne 3 ]]; then
        echo "usage: sshtunnel host remote-port local_port"
    else
        /usr/bin/ssh "$1" -L "$3":localhost:"$2"
    fi
}

# Function to cat files and conditionally copy content to the clipboard based on the OS
catfiles() {
    local os_type="$SYSTEM_OS_TYPE"
    local clip_cmd
    local all_contents=""
    local pattern="*"
    local recursive=false
    local use_find=false
    local use_json=false
    local json_output='{}'
    local temp_file=$(mktemp)
    local python_script=$(mktemp)

    # Parse options
    while getopts "rp:j" opt; do
        case ${opt} in
            r ) recursive=true; use_find=true ;;
            p ) pattern=$OPTARG; use_find=true ;;
            j ) use_json=true ;;
            \? ) echo "Usage: catfiles [-r] [-p pattern] [-j] [directory or files...]"; return 1 ;;
        esac
    done
    shift $((OPTIND -1))

    # Determine the appropriate clipboard command based on the platform
    case "$os_type" in
        OSX)
            clip_cmd="pbcopy"
            ;;
        LINUX)
            if command -v clip.exe &>/dev/null; then
                clip_cmd="clip.exe"
            elif command -v xclip &>/dev/null; then
                clip_cmd="xclip -selection clipboard"
            elif command -v xsel &>/dev/null; then
                clip_cmd="xsel --clipboard --input"
            else
                clip_cmd=""
            fi
            ;;
        *)
            clip_cmd=""
            ;;
    esac

    # Create Python script for JSON processing
    cat << 'EOF' > "$python_script"
import json
import sys

def escape_string(s):
    return s.encode("unicode_escape").decode("utf-8").replace('"', '\\"')

try:
    data = json.loads(sys.stdin.read())
    file_content = sys.argv[1]
    file_content = escape_string(file_content)
    file_data = {
        "filename": sys.argv[2],
        "relative_path": sys.argv[3],
        "file_size": sys.argv[4],
        "last_modified": sys.argv[5],
        "file_type": sys.argv[6],
        "line_count": int(sys.argv[7]),
        "file_extension": sys.argv[8],
        "md5_checksum": sys.argv[9],
        "content": file_content
    }
    data[sys.argv[3]] = file_data
    print(json.dumps(data, indent=2))
except Exception as e:
    print(json.dumps({"error": str(e)}), file=sys.stderr)
    sys.exit(1)
EOF

    # Function to process a single file
    process_file() {
        local file="$1"
        if [[ -f "$file" ]]; then
            local file_size=$(du -h "$file" | cut -f1)
            local last_modified=$(date -r "$file" "+%Y-%m-%d %H:%M:%S")
            local file_type=$(file -b "$file")
            local line_count=$(wc -l < "$file")
            local file_extension="${file##*.}"
            local full_path=$(realpath "$file")
            local relative_path=$(echo "$full_path" | sed "s|^$PWD/||")

            # Cross-platform MD5 checksum calculation
            local checksum
            if [[ "$os_type" == "OSX" ]]; then
                checksum=$(md5 -q "$file")
            else
                checksum=$(md5sum "$file" | cut -d' ' -f1)
            fi

            local file_content=$(<"$file")

            if $use_json; then
                python3 "$python_script" "$file_content" "$file" "$relative_path" "$file_size" "$last_modified" "$file_type" "$line_count" "$file_extension" "$checksum" <<< "$json_output" > "$temp_file"
                if [ $? -eq 0 ]; then
                    json_output=$(<"$temp_file")
                else
                    echo "Error processing file: $file" >&2
                    cat "$temp_file" >&2
                fi
            else
                all_contents+="
--- File Metadata ---
"
                all_contents+="Filename: $file
"
                all_contents+="Relative Path: $relative_path
"
                all_contents+="File Size: $file_size
"
                all_contents+="Last Modified: $last_modified
"
                all_contents+="File Type: $file_type
"
                all_contents+="Line Count: $line_count
"
                all_contents+="File Extension: $file_extension
"
                all_contents+="MD5 Checksum: $checksum
"
                all_contents+="--- File Contents ---
"
                all_contents+="$file_content

"
            fi
            echo "Filename: $file processed."
        else
            echo "Error: File $file does not exist or is a directory."
        fi
    }

    # Use find if recursive or pattern is specified, otherwise process arguments as files
    if $use_find; then
        local search_dir="${1:-.}"
        local find_cmd="find \"$search_dir\""
        if ! $recursive; then
            find_cmd+=" -maxdepth 1"
        fi
        find_cmd+=" -type f -name \"$pattern\""

        eval $find_cmd | while read -r file; do
            process_file "$file"
        done
    else
        # If no files specified, use current directory
        if [[ $# -eq 0 ]]; then
            for file in *(.) ; do  # This glob qualifier '(.)' ensures only regular files are matched
                process_file "$file"
            done
        else
            for file in "$@"; do
                process_file "$file"
            done
        fi
    fi

    # Finalize output
    if $use_json; then
        all_contents=$json_output
    fi

    # Pipe accumulated content to clipboard command or print to terminal
    if [[ -n $clip_cmd && -n "$all_contents" ]]; then
        echo "$all_contents" | $clip_cmd
        echo "All file contents copied to clipboard."
    elif [[ -n "$all_contents" ]]; then
        echo "$all_contents"
    else
        echo "No files were processed."
    fi

    # Clean up
    rm -f "$temp_file" "$python_script"
}

# Load and display environment variables from a .env file
loadenv() {
    if [ -f ".env" ]; then
        echo "Loading environment variables:"
        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ ! "$line" =~ ^# && "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
                varname=${line%%=*}
                export "$line"
                echo "Loaded: $varname"
            fi
        done < .env
        echo "All environment variables loaded successfully."
    else
        echo "Error: .env file does not exist in the current directory."
    fi
}

# Helper function for system recommendations
provide_quick_recommendations() {
    local recommendations=()

    if [[ "${memory_usage%\%}" -gt 90 ]]; then
        recommendations+=("- High memory usage detected. Consider closing unnecessary applications.")
    fi

if [[ $(echo "$cpu_load > $cpu_cores" | bc -l) -eq 1 ]]; then
        recommendations+=("- High CPU load detected. Check for resource-intensive processes.")
    fi

    if [[ ${#recommendations[@]} -gt 0 ]]; then
        printf "%s\n" "${recommendations[@]}"
    else
        echo "  Your system appears to be in good health. No specific recommendations at this time."
    fi
}

# OSC 7 directory tracking
osc7_cwd() {
    local hostname=${HOST:-$(hostname)}
    local url="file://${hostname}${PWD}"
    printf '\e]7;%s\a' "${url}"
}

d() { [[ -n $1 ]] && dirs "$@" || dirs -v; }
1() { cd -1; }
2() { cd -2; }
3() { cd -3; }
4() { cd -4; }
5() { cd -5; }

# Create directory and cd into it
mkcd() { mkdir -p "$@" && cd "$@"; }

# Extract various archive formats
extract() {
    if [ -f $1 ]; then
        case $1 in
            *.tar.bz2) tar xjf $1    ;;
            *.tar.gz)  tar xzf $1    ;;
            *.bz2)     bunzip2 $1    ;;
            *.rar)     unrar x $1    ;;
            *.gz)      gunzip $1     ;;
            *.tar)     tar xf $1     ;;
            *.tbz2)    tar xjf $1    ;;
            *.tgz)     tar xzf $1    ;;
            *.zip)     unzip $1      ;;
            *.Z)       uncompress $1 ;;
            *.7z)      7z x $1       ;;
            *)         echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}
