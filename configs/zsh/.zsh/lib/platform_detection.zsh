#!/bin/zsh
#
## Constants for cache directory and files
PLATFORM_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/platform"
PLATFORM_CACHE_FILE="$PLATFORM_CACHE_DIR/platform_info.cache"
PLATFORM_CACHE_TIMEOUT=3600  # Cache timeout in seconds

# Helper function to check capabilities without regex dependency
has_capability() {
    local capability="$1"
    local found=0

    # Simple array membership check
    for cap in "${SYSTEM_CAPABILITIES[@]}"; do
        if [[ "$cap" == "$capability" ]]; then
            found=1
            break
        fi
    done

    return $(( 1 - found ))
}

# Platform detection function
detect_platform() {
    local cache_age=0

    # Create cache directory if it doesn't exist
    mkdir -p "$PLATFORM_CACHE_DIR"

    # Check if cache exists and is recent
    if [[ -f "$PLATFORM_CACHE_FILE" ]]; then
        # Platform-independent stat command
        if [[ "$OSTYPE" == darwin* ]]; then
            cache_age=$(($(date +%s) - $(stat -f %m "$PLATFORM_CACHE_FILE" 2>/dev/null)))
        else
            cache_age=$(($(date +%s) - $(stat -c %Y "$PLATFORM_CACHE_FILE" 2>/dev/null)))
        fi
    fi

    # Return cached results if they exist and are recent
    if [[ -f "$PLATFORM_CACHE_FILE" ]] && [[ $cache_age -lt $PLATFORM_CACHE_TIMEOUT ]]; then
        source "$PLATFORM_CACHE_FILE"
        return
    fi

    # Start fresh platform detection
    local os_type=""
    local os_version=""
    local arch=""
    local distro=""
    local distro_version=""
    local package_manager=""
    local init_system=""

    # Detect base OS type
    case "$OSTYPE" in
        darwin*)
            os_type="OSX"
            os_version=$(sw_vers -productVersion)
            package_manager="brew"
            init_system="launchd"
            ;;
        linux*)
            os_type="LINUX"
            # Detect Linux distribution
            if [[ -f /etc/os-release ]]; then
                source /etc/os-release
                distro="$ID"
                distro_version="$VERSION_ID"
            elif [[ -f /etc/lsb-release ]]; then
                source /etc/lsb-release
                distro="$DISTRIB_ID"
                distro_version="$DISTRIB_RELEASE"
            fi

            # Detect package manager
            if command -v apt-get >/dev/null 2>&1; then
                package_manager="apt"
            elif command -v dnf >/dev/null 2>&1; then
                package_manager="dnf"
            elif command -v yum >/dev/null 2>&1; then
                package_manager="yum"
            elif command -v pacman >/dev/null 2>&1; then
                package_manager="pacman"
            fi

            # Detect init system
            if [[ "$(ps -p 1 -o comm=)" == "systemd" ]]; then
                init_system="systemd"
            elif [[ -f /etc/init.d/cron && ! -h /etc/init.d/cron ]]; then
                init_system="sysvinit"
            elif [[ -d /etc/openrc ]]; then
                init_system="openrc"
            fi
            ;;
        freebsd*)
            os_type="BSD"
            os_version=$(uname -r)
            package_manager="pkg"
            init_system="rc"
            ;;
        msys*|cygwin*)
            os_type="WINDOWS"
            os_version=$(cmd /c ver | grep -o '[0-9].[0-9].[0-9]*')
            package_manager="choco"
            init_system="windows"
            ;;
        *)
            os_type="UNKNOWN"
            os_version="UNKNOWN"
            ;;
    esac

    # Detect architecture
    case "$(uname -m)" in
        x86_64)
            arch="x86_64"
            # Detect Rosetta on macOS
            if [[ "$os_type" == "OSX" ]] && sysctl -n sysctl.proc_translated >/dev/null 2>&1; then
                arch="x86_64-rosetta"
            fi
            ;;
        arm64|aarch64)
            arch="arm64"
            ;;
        armv7*)
            arch="armv7"
            ;;
        *)
            arch="$(uname -m)"
            ;;
    esac

    # Detect virtualization
    local virt="none"
    if [[ -f /proc/cpuinfo ]] && grep -q "hypervisor" /proc/cpuinfo; then
        virt="vm"
    elif [[ -d /proc/vz ]]; then
        virt="openvz"
    elif command -v systemd-detect-virt >/dev/null 2>&1; then
        virt=$(systemd-detect-virt)
    elif [[ "$os_type" == "OSX" ]] && sysctl -n machdep.cpu.features | grep -q "VMM"; then
        virt="vm"
    fi

    # Additional system capabilities
    local capabilities=()
    if command -v systemctl >/dev/null 2>&1; then capabilities+=("systemd"); fi
    if command -v docker >/dev/null 2>&1; then capabilities+=("docker"); fi
    if command -v podman >/dev/null 2>&1; then capabilities+=("podman"); fi
    if [[ -S "${XDG_RUNTIME_DIR:-/run/user/$UID}/podman/podman.sock" ]]; then capabilities+=("rootless-podman"); fi
    if command -v nix-env >/dev/null 2>&1; then capabilities+=("nix"); fi
    if [[ -d "/opt/homebrew" ]]; then capabilities+=("homebrew"); fi

    # Create cache file with detected information
    cat > "$PLATFORM_CACHE_FILE" <<EOF
# Platform detection cache generated at $(date)
export SYSTEM_OS_TYPE="$os_type"
export SYSTEM_OS_VERSION="$os_version"
export SYSTEM_ARCH="$arch"
export SYSTEM_DISTRO="$distro"
export SYSTEM_DISTRO_VERSION="$distro_version"
export SYSTEM_PACKAGE_MANAGER="$package_manager"
export SYSTEM_INIT="$init_system"
export SYSTEM_VIRT="$virt"
export SYSTEM_CAPABILITIES=(${capabilities[*]})
EOF

    # Source the newly created cache file
    source "$PLATFORM_CACHE_FILE"
}

# Helper functions for platform-specific operations
is_osx() {
    [[ "$SYSTEM_OS_TYPE" == "OSX" ]]
}

is_linux() {
    [[ "$SYSTEM_OS_TYPE" == "LINUX" ]]
}

is_bsd() {
    [[ "$SYSTEM_OS_TYPE" == "BSD" ]]
}

is_windows() {
    [[ "$SYSTEM_OS_TYPE" == "WINDOWS" ]]
}

is_arm() {
    [[ "$SYSTEM_ARCH" == "arm64" || "$SYSTEM_ARCH" == "armv7" ]]
}

is_x86() {
    [[ "$SYSTEM_ARCH" == "x86_64" || "$SYSTEM_ARCH" == "x86_64-rosetta" ]]
}

# Function to print system information
print_system_info() {
    cat <<EOF
System Information:
------------------
OS Type: $SYSTEM_OS_TYPE
OS Version: $SYSTEM_OS_VERSION
Architecture: $SYSTEM_ARCH
Distribution: $SYSTEM_DISTRO
Distribution Version: $SYSTEM_DISTRO_VERSION
Package Manager: $SYSTEM_PACKAGE_MANAGER
Init System: $SYSTEM_INIT
Virtualization: $SYSTEM_VIRT
Capabilities: ${SYSTEM_CAPABILITIES[@]}
EOF
}

# Initialize platform detection when the module is sourced
detect_platform
