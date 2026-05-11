#!/bin/zsh
#
# Platform detection — sets SYSTEM_* variables and helper functions

# Helper function to check capabilities
has_capability() {
    local capability="$1"
    for cap in "${SYSTEM_CAPABILITIES[@]}"; do
        [[ "$cap" == "$capability" ]] && return 0
    done
    return 1
}

# Detect platform and set variables
detect_platform() {
    # OS type
    case "$OSTYPE" in
        darwin*)  SYSTEM_OS_TYPE="OSX" ;;
        linux*)   SYSTEM_OS_TYPE="LINUX" ;;
        freebsd*) SYSTEM_OS_TYPE="BSD" ;;
        *)        SYSTEM_OS_TYPE="UNKNOWN" ;;
    esac

    # Architecture
    case "$(uname -m)" in
        x86_64)       SYSTEM_ARCH="x86_64" ;;
        arm64|aarch64) SYSTEM_ARCH="arm64" ;;
        *)            SYSTEM_ARCH="$(uname -m)" ;;
    esac

    # Capabilities
    SYSTEM_CAPABILITIES=()
    command -v nix-env &>/dev/null && SYSTEM_CAPABILITIES+=("nix")
    [[ -d "/opt/homebrew" ]] && SYSTEM_CAPABILITIES+=("homebrew")
    command -v docker &>/dev/null && SYSTEM_CAPABILITIES+=("docker")
    command -v systemctl &>/dev/null && SYSTEM_CAPABILITIES+=("systemd")

    export SYSTEM_OS_TYPE SYSTEM_ARCH SYSTEM_CAPABILITIES
}

# Helper functions
is_osx()     { [[ "$SYSTEM_OS_TYPE" == "OSX" ]]; }
is_linux()   { [[ "$SYSTEM_OS_TYPE" == "LINUX" ]]; }
is_arm()     { [[ "$SYSTEM_ARCH" == "arm64" ]]; }

# Run on source
detect_platform
