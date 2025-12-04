#!/bin/zsh

# Find gum executable path (used by multiple modules)
get_gum_path() {
    local gum_path

    # First check if gum exists in PATH
    if command -v gum >/dev/null 2>&1; then
        gum_path=$(command -v gum)
    # Then check Homebrew location on macOS
    elif [[ -x "/opt/homebrew/bin/gum" ]]; then
        gum_path="/opt/homebrew/bin/gum"
    # Finally check common Linux location
    elif [[ -x "/usr/bin/gum" ]]; then
        gum_path="/usr/bin/gum"
    else
        echo ""
        return 1
    fi

    echo "$gum_path"
}

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

# Get platform-appropriate clipboard command
_get_clipboard_cmd() {
    case "$SYSTEM_OS_TYPE" in
        OSX) echo "pbcopy" ;;
        LINUX)
            if command -v clip.exe &>/dev/null; then echo "clip.exe"
            elif command -v xclip &>/dev/null; then echo "xclip -selection clipboard"
            elif command -v xsel &>/dev/null; then echo "xsel --clipboard --input"
            fi ;;
    esac
}

# Get file metadata as pipe-separated values
_get_file_metadata() {
    local file=$1
    local file_size=$(du -h "$file" | cut -f1)
    local last_modified=$(date -r "$file" "+%Y-%m-%d %H:%M:%S")
    local file_type=$(file -b "$file")
    local line_count=$(wc -l < "$file")
    local file_extension="${file##*.}"
    local full_path=$(realpath "$file")
    local relative_path="${full_path#$PWD/}"
    local checksum
    if [[ "$SYSTEM_OS_TYPE" == "OSX" ]]; then
        checksum=$(md5 -q "$file")
    else
        checksum=$(md5sum "$file" | cut -d' ' -f1)
    fi
    echo "${file_size}|${last_modified}|${file_type}|${line_count}|${file_extension}|${relative_path}|${checksum}"
}

# Format file with metadata as text
_format_file_text() {
    local file=$1 metadata=$2 content=$3
    local size modified type lines ext path checksum
    IFS='|' read -r size modified type lines ext path checksum <<< "$metadata"
    cat <<EOF
--- File Metadata ---
Filename: $file
Relative Path: $path
File Size: $size
Last Modified: $modified
File Type: $type
Line Count: $lines
File Extension: $ext
MD5 Checksum: $checksum
--- File Contents ---
$content

EOF
}

# Cat files with metadata, optionally copy to clipboard
# Usage: catfiles [-r] [-p pattern] [-j] [directory or files...]
catfiles() {
    local pattern="*" recursive=false use_find=false use_json=false
    local all_contents="" json_output='{}'

    while getopts "rp:j" opt; do
        case ${opt} in
            r ) recursive=true; use_find=true ;;
            p ) pattern=$OPTARG; use_find=true ;;
            j ) use_json=true ;;
            \? ) echo "Usage: catfiles [-r] [-p pattern] [-j] [directory or files...]"; return 1 ;;
        esac
    done
    shift $((OPTIND -1))

    local clip_cmd=$(_get_clipboard_cmd)
    local temp_file=$(mktemp)

    # Python script for JSON processing
    local python_script=$(mktemp)
    cat << 'PYEOF' > "$python_script"
import json, sys
try:
    data = json.loads(sys.stdin.read())
    content = sys.argv[1].encode("unicode_escape").decode("utf-8").replace('"', '\\"')
    data[sys.argv[3]] = {
        "filename": sys.argv[2], "relative_path": sys.argv[3], "file_size": sys.argv[4],
        "last_modified": sys.argv[5], "file_type": sys.argv[6], "line_count": int(sys.argv[7]),
        "file_extension": sys.argv[8], "md5_checksum": sys.argv[9], "content": content
    }
    print(json.dumps(data, indent=2))
except Exception as e:
    print(json.dumps({"error": str(e)}), file=sys.stderr); sys.exit(1)
PYEOF

    # Process a single file
    _process_file() {
        local file=$1
        [[ ! -f "$file" ]] && { echo "Error: $file does not exist or is a directory." >&2; return; }

        local metadata=$(_get_file_metadata "$file")
        local content=$(<"$file")
        local size modified type lines ext path checksum
        IFS='|' read -r size modified type lines ext path checksum <<< "$metadata"

        if $use_json; then
            python3 "$python_script" "$content" "$file" "$path" "$size" "$modified" "$type" "$lines" "$ext" "$checksum" <<< "$json_output" > "$temp_file"
            [[ $? -eq 0 ]] && json_output=$(<"$temp_file") || { echo "Error processing: $file" >&2; cat "$temp_file" >&2; }
        else
            all_contents+=$(_format_file_text "$file" "$metadata" "$content")
        fi
        echo "Processed: $file"
    }

    # Iterate over files
    if $use_find; then
        local search_dir="${1:-.}"
        local find_opts=(-type f -name "$pattern")
        $recursive || find_opts=(-maxdepth 1 "${find_opts[@]}")
        find "$search_dir" "${find_opts[@]}" | while read -r file; do _process_file "$file"; done
    elif [[ $# -eq 0 ]]; then
        for file in *(.) ; do _process_file "$file"; done
    else
        for file in "$@"; do _process_file "$file"; done
    fi

    # Output results
    $use_json && all_contents=$json_output
    if [[ -n "$clip_cmd" && -n "$all_contents" ]]; then
        echo "$all_contents" | eval $clip_cmd
        echo "All file contents copied to clipboard."
    elif [[ -n "$all_contents" ]]; then
        echo "$all_contents"
    else
        echo "No files were processed."
    fi

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
