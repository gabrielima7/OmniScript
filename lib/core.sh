#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  OmniScript - Core Library                                                 ║
# ║  Essential functions, OS detection, and bootstrapping                      ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
# shellcheck disable=SC2034

# Prevent double sourcing
[[ -n "${_OS_CORE_LOADED:-}" ]] && return 0
readonly _OS_CORE_LOADED=1

# ═══════════════════════════════════════════════════════════════════════════
# OS Detection
# ═══════════════════════════════════════════════════════════════════════════

# Detect operating system and set related variables
os_detect_os() {
    OS_ID=""
    OS_ID_LIKE=""
    OS_VERSION_ID=""
    OS_PRETTY_NAME=""
    OS_ARCH=""
    OS_PKG_MANAGER=""
    
    # Get architecture
    OS_ARCH=$(uname -m)
    case "$OS_ARCH" in
        x86_64)  OS_ARCH="amd64" ;;
        aarch64) OS_ARCH="arm64" ;;
        armv7l)  OS_ARCH="armv7" ;;
    esac
    
    # Parse /etc/os-release
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        OS_ID="${ID:-unknown}"
        OS_ID_LIKE="${ID_LIKE:-}"
        OS_VERSION_ID="${VERSION_ID:-}"
        OS_PRETTY_NAME="${PRETTY_NAME:-$OS_ID}"
    elif [[ -f /etc/alpine-release ]]; then
        OS_ID="alpine"
        OS_VERSION_ID=$(cat /etc/alpine-release)
        OS_PRETTY_NAME="Alpine Linux ${OS_VERSION_ID}"
    else
        OS_ID="unknown"
        OS_PRETTY_NAME="Unknown Linux"
    fi
    
    # Determine package manager
    case "$OS_ID" in
        debian|ubuntu|linuxmint|pop|zorin|elementary|kali)
            OS_PKG_MANAGER="apt"
            ;;
        fedora|rhel|centos|rocky|alma|oracle)
            OS_PKG_MANAGER="dnf"
            ;;
        alpine)
            OS_PKG_MANAGER="apk"
            ;;
        arch|manjaro|endeavouros|garuda)
            OS_PKG_MANAGER="pacman"
            ;;
        opensuse*|suse|sles)
            OS_PKG_MANAGER="zypper"
            ;;
        *)
            # Try to detect based on available commands
            if command -v apt &>/dev/null; then
                OS_PKG_MANAGER="apt"
            elif command -v dnf &>/dev/null; then
                OS_PKG_MANAGER="dnf"
            elif command -v yum &>/dev/null; then
                OS_PKG_MANAGER="dnf"
            elif command -v apk &>/dev/null; then
                OS_PKG_MANAGER="apk"
            elif command -v pacman &>/dev/null; then
                OS_PKG_MANAGER="pacman"
            elif command -v zypper &>/dev/null; then
                OS_PKG_MANAGER="zypper"
            else
                OS_PKG_MANAGER="unknown"
            fi
            ;;
    esac
    
    export OS_ID OS_ID_LIKE OS_VERSION_ID OS_PRETTY_NAME OS_ARCH OS_PKG_MANAGER
}

# ═══════════════════════════════════════════════════════════════════════════
# Privilege Management
# ═══════════════════════════════════════════════════════════════════════════

# Check if running as root
os_is_root() {
    [[ $EUID -eq 0 ]]
}

# Require root privileges
os_require_root() {
    if ! os_is_root; then
        os_log_error "This operation requires root privileges"
        os_log_info "Please run with sudo or as root"
        exit 1
    fi
}

# Get appropriate sudo command (empty if root)
os_sudo() {
    if os_is_root; then
        "$@"
    else
        sudo "$@"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# Error Handling & Cleanup
# ═══════════════════════════════════════════════════════════════════════════

# Array to store cleanup functions
declare -a OS_CLEANUP_HANDLERS=()

# Register a cleanup handler
os_register_cleanup() {
    OS_CLEANUP_HANDLERS+=("$1")
}

# Execute all cleanup handlers
os_cleanup() {
    local exit_code=$?
    
    for handler in "${OS_CLEANUP_HANDLERS[@]}"; do
        if declare -f "$handler" &>/dev/null; then
            "$handler" || true
        fi
    done
    
    exit $exit_code
}

# Set up trap for cleanup
trap os_cleanup EXIT INT TERM

# ═══════════════════════════════════════════════════════════════════════════
# Utility Functions
# ═══════════════════════════════════════════════════════════════════════════

# Check if a command exists
os_command_exists() {
    command -v "$1" &>/dev/null
}

# Check if running in a container
os_is_container() {
    [[ -f /.dockerenv ]] || 
    grep -q 'docker\|lxc\|containerd' /proc/1/cgroup 2>/dev/null ||
    [[ -n "${container:-}" ]]
}

# Check if string is empty
os_is_empty() {
    [[ -z "${1:-}" ]]
}

# Check if string is not empty
os_is_not_empty() {
    [[ -n "${1:-}" ]]
}

# Check if variable is set
os_is_set() {
    [[ -v "$1" ]]
}

# Trim whitespace from string
os_trim() {
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
}

# Convert string to lowercase
os_lowercase() {
    printf '%s' "${1,,}"
}

# Convert string to uppercase
os_uppercase() {
    printf '%s' "${1^^}"
}

# Generate a random string
os_random_string() {
    local length="${1:-32}"
    tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c "$length"
}

# Get timestamp in ISO format
os_timestamp() {
    date '+%Y-%m-%dT%H:%M:%S%z'
}

# URL encode a string
os_urlencode() {
    local string="$1"
    local strlen=${#string}
    local encoded=""
    local pos c o
    
    for ((pos = 0; pos < strlen; pos++)); do
        c=${string:$pos:1}
        case "$c" in
            [-_.~a-zA-Z0-9]) o="$c" ;;
            *) printf -v o '%%%02X' "'$c" ;;
        esac
        encoded+="$o"
    done
    
    printf '%s' "$encoded"
}

# ═══════════════════════════════════════════════════════════════════════════
# HTTP Utilities (curl wrapper)
# ═══════════════════════════════════════════════════════════════════════════

# Simple HTTP GET request
os_http_get() {
    local url="$1"
    local headers="${2:-}"
    
    local curl_args=(-sSL --connect-timeout 10 --max-time 30)
    
    if [[ -n "$headers" ]]; then
        curl_args+=(-H "$headers")
    fi
    
    curl "${curl_args[@]}" "$url"
}

# HTTP GET with JSON response parsing (requires jq)
os_http_get_json() {
    local url="$1"
    local jq_filter="${2:-.}"
    
    os_http_get "$url" "Accept: application/json" | jq -r "$jq_filter"
}

# ═══════════════════════════════════════════════════════════════════════════
# File System Utilities
# ═══════════════════════════════════════════════════════════════════════════

# Create directory if it doesn't exist
os_ensure_dir() {
    local dir="$1"
    [[ -d "$dir" ]] || mkdir -p "$dir"
}

# Check if file is readable
os_is_readable() {
    [[ -r "$1" ]]
}

# Check if file is writable
os_is_writable() {
    [[ -w "$1" ]]
}

# Check if path is a directory
os_is_directory() {
    [[ -d "$1" ]]
}

# Check if path is a file
os_is_file() {
    [[ -f "$1" ]]
}

# Get file size in bytes
os_file_size() {
    stat -c %s "$1" 2>/dev/null || stat -f %z "$1" 2>/dev/null
}

# ═══════════════════════════════════════════════════════════════════════════
# Runtime Installation
# ═══════════════════════════════════════════════════════════════════════════

# Install Docker
os_install_docker() {
    os_log_info "Installing Docker..."
    
    os_require_root
    
    case "$OS_PKG_MANAGER" in
        apt)
            os_sudo apt-get update
            os_sudo apt-get install -y ca-certificates curl gnupg
            os_sudo install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/${OS_ID}/gpg | os_sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            os_sudo chmod a+r /etc/apt/keyrings/docker.gpg
            
            echo \
              "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${OS_ID} \
              $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
              os_sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            os_sudo apt-get update
            os_sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;
        dnf)
            os_sudo dnf -y install dnf-plugins-core
            os_sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
            os_sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;
        apk)
            os_sudo apk add docker docker-cli-compose
            os_sudo rc-update add docker default
            ;;
        pacman)
            os_sudo pacman -Sy --noconfirm docker docker-compose
            ;;
        zypper)
            os_sudo zypper install -y docker docker-compose
            ;;
    esac
    
    os_sudo systemctl enable --now docker 2>/dev/null || os_sudo service docker start
    os_log_success "Docker installed successfully!"
}

# Install Podman
os_install_podman() {
    os_log_info "Installing Podman..."
    
    os_require_root
    
    case "$OS_PKG_MANAGER" in
        apt)
            os_sudo apt-get update
            os_sudo apt-get install -y podman podman-compose
            ;;
        dnf)
            os_sudo dnf install -y podman podman-compose
            ;;
        apk)
            os_sudo apk add podman podman-compose
            ;;
        pacman)
            os_sudo pacman -Sy --noconfirm podman podman-compose
            ;;
        zypper)
            os_sudo zypper install -y podman podman-compose
            ;;
    esac
    
    os_log_success "Podman installed successfully!"
}

# Install LXD
os_install_lxd() {
    os_log_info "Installing LXD..."
    
    os_require_root
    
    case "$OS_PKG_MANAGER" in
        apt)
            if os_command_exists snap; then
                os_sudo snap install lxd
            else
                os_sudo apt-get update
                os_sudo apt-get install -y lxd lxd-client
            fi
            ;;
        dnf)
            os_sudo dnf install -y lxd
            ;;
        apk)
            os_sudo apk add lxd
            ;;
        pacman)
            os_sudo pacman -Sy --noconfirm lxd
            ;;
        zypper)
            os_sudo zypper install -y lxd
            ;;
    esac
    
    # Initialize LXD with defaults
    os_sudo lxd init --auto 2>/dev/null || true
    
    os_log_success "LXD installed successfully!"
}

# ═══════════════════════════════════════════════════════════════════════════
# Package Manager Loading
# ═══════════════════════════════════════════════════════════════════════════

os_load_package_manager() {
    local pkg_path="${OS_PKG_DIR}/${OS_PKG_MANAGER}.sh"
    
    if [[ -f "$pkg_path" ]]; then
        # shellcheck source=/dev/null
        source "$pkg_path"
    else
        os_log_warn "Package manager adapter not found: ${OS_PKG_MANAGER}"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# Initialization
# ═══════════════════════════════════════════════════════════════════════════

# Detect OS on load
os_detect_os
