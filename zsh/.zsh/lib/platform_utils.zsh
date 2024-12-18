#!/bin/zsh

setup_platform_binary() {
    local binary_name="$1"
    local common_link="$HOME/bin/$binary_name"
    local binary_path

    if is_osx; then
        if is_arm; then
            binary_path="$HOME/bin/${binary_name}-darwin-arm64"
        else
            binary_path="$HOME/bin/${binary_name}-darwin-amd64"
        fi
    elif is_linux; then
        if is_arm; then
            binary_path="$HOME/bin/${binary_name}-linux-arm64"
        else
            binary_path="$HOME/bin/${binary_name}-linux-amd64"
        fi
    else
        echo "Unsupported platform for $binary_name"
        return 1
    fi

    if [[ -n "$binary_path" ]] && [[ -x "$binary_path" ]]; then
        [[ ! -L "$common_link" ]] || [[ "$(readlink -- "$common_link")" != "$binary_path" ]] && \
            ln -sf "$binary_path" "$common_link"
        return 0
    fi

    echo "$binary_name binary not found or not executable at $binary_path"
    return 1
}
