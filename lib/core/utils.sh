#!/usr/bin/env bash
#===============================================================================
# OmniScript - Core Utilities Library
# Common utility functions for logging, validation, and operations
#===============================================================================
# shellcheck disable=SC2034

#-------------------------------------------------------------------------------
# Logging
#-------------------------------------------------------------------------------
declare -gA OS_LOG_LEVELS=(
    [DEBUG]=0
    [INFO]=1
    [WARN]=2
    [ERROR]=3
    [FATAL]=4
)

OS_CURRENT_LOG_LEVEL="${OS_LOG_LEVEL:-INFO}"

os_log() {
    local level="${1^^}"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    local level_num="${OS_LOG_LEVELS[$level]:-1}"
    local current_num="${OS_LOG_LEVELS[$OS_CURRENT_LOG_LEVEL]:-1}"
    
    if [[ $level_num -ge $current_num ]]; then
        echo "[${timestamp}] [${level}] ${message}" >> "${OS_LOG_FILE:-/dev/null}"
        
        if [[ "${OS_VERBOSE:-false}" == "true" ]] || [[ "$level" == "ERROR" ]] || [[ "$level" == "FATAL" ]]; then
            case "$level" in
                DEBUG) echo -e "${C_DIM}[DEBUG]${C_RESET} ${message}" >&2 ;;
                INFO)  echo -e "${C_CYAN}[INFO]${C_RESET} ${message}" ;;
                WARN)  echo -e "${C_YELLOW}[WARN]${C_RESET} ${message}" >&2 ;;
                ERROR) echo -e "${C_RED}[ERROR]${C_RESET} ${message}" >&2 ;;
                FATAL) echo -e "${C_RED}${C_BOLD}[FATAL]${C_RESET} ${message}" >&2 ;;
            esac
        fi
    fi
}

os_debug() { os_log "DEBUG" "$1"; }
os_info() { os_log "INFO" "$1"; }
os_warn() { os_log "WARN" "$1"; }
os_error() { os_log "ERROR" "$1"; }
os_fatal() { os_log "FATAL" "$1"; exit 1; }

#-------------------------------------------------------------------------------
# Command Execution
#-------------------------------------------------------------------------------
os_run() {
    local cmd="$*"
    os_debug "Executing: ${cmd}"
    
    if [[ "${OS_VERBOSE:-false}" == "true" ]]; then
        eval "$cmd"
    else
        eval "$cmd" 2>&1 | while read -r line; do
            os_debug "$line"
        done
    fi
    
    return "${PIPESTATUS[0]}"
}

os_run_sudo() {
    local cmd="$*"
    
    if [[ $EUID -eq 0 ]]; then
        os_run "$cmd"
    else
        os_debug "Executing with sudo: ${cmd}"
        sudo bash -c "$cmd"
    fi
}

#-------------------------------------------------------------------------------
# Validation
#-------------------------------------------------------------------------------
os_require_root() {
    if [[ $EUID -ne 0 ]]; then
        os_fatal "This operation requires root privileges. Please run with sudo."
    fi
}

os_require_command() {
    local cmd="$1"
    local package="${2:-$1}"
    
    if ! command -v "$cmd" &> /dev/null; then
        os_error "Required command not found: ${cmd}"
        os_info "Install with: ${OS_PKG_INSTALL} ${package}"
        return 1
    fi
    return 0
}

os_require_commands() {
    local missing=()
    
    for cmd in "$@"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        os_error "Missing required commands: ${missing[*]}"
        return 1
    fi
    return 0
}

os_is_port_available() {
    local port="$1"
    
    if command -v ss &> /dev/null; then
        ! ss -tuln | grep -q ":${port}\b"
    elif command -v netstat &> /dev/null; then
        ! netstat -tuln | grep -q ":${port}\b"
    else
        # Assume available if we can't check
        return 0
    fi
}

os_find_available_port() {
    local start_port="${1:-8000}"
    local port="$start_port"
    
    while ! os_is_port_available "$port"; do
        ((port++))
        if [[ $port -gt 65535 ]]; then
            os_error "No available ports found starting from ${start_port}"
            return 1
        fi
    done
    
    echo "$port"
}

#-------------------------------------------------------------------------------
# String Operations
#-------------------------------------------------------------------------------
os_trim() {
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    echo -n "$var"
}

os_to_lower() {
    echo "${1,,}"
}

os_to_upper() {
    echo "${1^^}"
}

os_slugify() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/-\+/-/g' | sed 's/^-\|-$//g'
}

#-------------------------------------------------------------------------------
# File Operations
#-------------------------------------------------------------------------------
os_backup_file() {
    local file="$1"
    local backup_dir="${2:-${OS_DATA_DIR}/backups}"
    
    if [[ -f "$file" ]]; then
        mkdir -p "$backup_dir"
        local timestamp
        timestamp=$(date '+%Y%m%d_%H%M%S')
        local backup_name
        backup_name="$(basename "$file").${timestamp}.bak"
        cp "$file" "${backup_dir}/${backup_name}"
        os_debug "Backed up ${file} to ${backup_dir}/${backup_name}"
        echo "${backup_dir}/${backup_name}"
    fi
}

os_create_temp_dir() {
    mktemp -d -t omniscript.XXXXXX
}

os_safe_write() {
    local file="$1"
    local content="$2"
    local dir
    dir=$(dirname "$file")
    
    mkdir -p "$dir"
    
    local temp_file
    temp_file=$(mktemp)
    echo "$content" > "$temp_file"
    mv "$temp_file" "$file"
}

#-------------------------------------------------------------------------------
# Network Operations  
#-------------------------------------------------------------------------------
os_download() {
    local url="$1"
    local output="${2:--}"
    
    if command -v curl &> /dev/null; then
        curl -fsSL "$url" ${output:+-o "$output"}
    elif command -v wget &> /dev/null; then
        wget -qO "${output:--}" "$url"
    else
        os_fatal "Neither curl nor wget available"
    fi
}

os_api_get() {
    local url="$1"
    local headers=("${@:2}")
    local curl_args=(-fsSL)
    
    for header in "${headers[@]}"; do
        curl_args+=(-H "$header")
    done
    
    curl "${curl_args[@]}" "$url"
}

os_wait_for_url() {
    local url="$1"
    local timeout="${2:-60}"
    local interval="${3:-2}"
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        if curl -fsSL -o /dev/null "$url" 2>/dev/null; then
            return 0
        fi
        sleep "$interval"
        ((elapsed += interval))
    done
    
    return 1
}

#-------------------------------------------------------------------------------
# JSON Operations (using jq if available, fallback to grep/sed)
#-------------------------------------------------------------------------------
os_json_get() {
    local json="$1"
    local key="$2"
    
    if command -v jq &> /dev/null; then
        echo "$json" | jq -r ".$key // empty"
    else
        # Basic fallback - only works for simple keys
        echo "$json" | grep -oP "\"${key}\"\s*:\s*\"\K[^\"]*" | head -1
    fi
}

os_json_array_get() {
    local json="$1"
    local index="$2"
    
    if command -v jq &> /dev/null; then
        echo "$json" | jq -r ".[$index] // empty"
    fi
}

#-------------------------------------------------------------------------------
# Array Operations
#-------------------------------------------------------------------------------
os_array_contains() {
    local needle="$1"
    shift
    local hay
    
    for hay in "$@"; do
        [[ "$hay" == "$needle" ]] && return 0
    done
    return 1
}

os_array_join() {
    local delimiter="$1"
    shift
    local first="$1"
    shift
    
    printf "%s" "$first"
    printf "%s" "${@/#/$delimiter}"
}

#-------------------------------------------------------------------------------
# Config Operations
#-------------------------------------------------------------------------------
os_config_get() {
    local key="$1"
    local default="${2:-}"
    local config_file="${OS_CONFIG_FILE}"
    
    if [[ -f "$config_file" ]]; then
        local value
        value=$(grep "^${key}=" "$config_file" 2>/dev/null | cut -d'=' -f2- | sed 's/^["'"'"']//;s/["'"'"']$//')
        echo "${value:-$default}"
    else
        echo "$default"
    fi
}

os_config_set() {
    local key="$1"
    local value="$2"
    local config_file="${OS_CONFIG_FILE}"
    
    mkdir -p "$(dirname "$config_file")"
    touch "$config_file"
    
    if grep -q "^${key}=" "$config_file" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=\"${value}\"|" "$config_file"
    else
        echo "${key}=\"${value}\"" >> "$config_file"
    fi
}

#-------------------------------------------------------------------------------
# Version Comparison
#-------------------------------------------------------------------------------
os_version_compare() {
    local v1="$1"
    local op="$2"
    local v2="$3"
    
    # Remove 'v' prefix if present
    v1="${v1#v}"
    v2="${v2#v}"
    
    case "$op" in
        eq|"=")  [[ "$v1" == "$v2" ]] ;;
        ne|"!=") [[ "$v1" != "$v2" ]] ;;
        lt|"<")  [[ "$(printf '%s\n' "$v1" "$v2" | sort -V | head -n1)" == "$v1" ]] && [[ "$v1" != "$v2" ]] ;;
        le|"<=") [[ "$(printf '%s\n' "$v1" "$v2" | sort -V | head -n1)" == "$v1" ]] ;;
        gt|">")  [[ "$(printf '%s\n' "$v1" "$v2" | sort -V | head -n1)" == "$v2" ]] && [[ "$v1" != "$v2" ]] ;;
        ge|">=") [[ "$(printf '%s\n' "$v1" "$v2" | sort -V | head -n1)" == "$v2" ]] ;;
        *) return 1 ;;
    esac
}

#-------------------------------------------------------------------------------
# Initialization Flag
#-------------------------------------------------------------------------------
OS_UTILS_LOADED=true
