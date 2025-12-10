#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  OmniScript - Base Adapter Interface                                       ║
# ║  Abstract interface that all target adapters must implement                ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

[[ -n "${_OS_ADAPTER_BASE_LOADED:-}" ]] && return 0
readonly _OS_ADAPTER_BASE_LOADED=1

# Current adapter info
ADAPTER_NAME=""
ADAPTER_TYPE=""

# Validate adapter implementation
os_validate_adapter() {
    local required_functions=(
        "adapter_install"
        "adapter_start"
        "adapter_stop"
        "adapter_status"
        "adapter_logs"
        "adapter_backup"
        "adapter_restore"
        "adapter_update"
        "adapter_remove"
    )
    
    for func in "${required_functions[@]}"; do
        if ! declare -f "$func" &>/dev/null; then
            os_log_error "Adapter missing required function: $func"
            return 1
        fi
    done
    
    return 0
}

# Generate container/service name
os_generate_name() {
    local app_name="$1"
    local prefix="${2:-os}"
    echo "${prefix}-${app_name}-$(os_random_string 6 | tr '[:upper:]' '[:lower:]')"
}

# Get data directory for app
os_get_app_data_dir() {
    local app_name="$1"
    echo "${OS_CONFIG_DIR}/data/${app_name}"
}

# Create app data directory
os_ensure_app_data_dir() {
    local app_name="$1"
    local data_dir
    data_dir=$(os_get_app_data_dir "$app_name")
    os_ensure_dir "$data_dir"
    echo "$data_dir"
}

# Track installed app
os_track_installation() {
    local app_name="$1"
    local target="$2"
    local container_id="${3:-}"
    
    local track_file="${OS_CONFIG_DIR}/installed.json"
    local timestamp
    timestamp=$(date -Iseconds)
    
    # Simple append to tracking file
    echo "{\"app\":\"${app_name}\",\"target\":\"${target}\",\"id\":\"${container_id}\",\"installed\":\"${timestamp}\"}" >> "$track_file"
}

# List installed apps
os_list_installed() {
    local track_file="${OS_CONFIG_DIR}/installed.json"
    
    if [[ ! -f "$track_file" ]]; then
        os_log_info "No applications installed yet"
        return 0
    fi
    
    os_log_section "Installed Applications"
    echo ""
    
    local headers=("NAME" "TARGET" "INSTALLED")
    local rows=()
    
    while IFS= read -r line; do
        local app target installed
        app=$(echo "$line" | grep -oP '"app":"\K[^"]+')
        target=$(echo "$line" | grep -oP '"target":"\K[^"]+')
        installed=$(echo "$line" | grep -oP '"installed":"\K[^"]+')
        rows+=("${app}|${target}|${installed}")
    done < "$track_file"
    
    os_table headers rows
}

# Remove app from tracking
os_untrack_installation() {
    local app_name="$1"
    local track_file="${OS_CONFIG_DIR}/installed.json"
    
    if [[ -f "$track_file" ]]; then
        grep -v "\"app\":\"${app_name}\"" "$track_file" > "${track_file}.tmp" || true
        mv "${track_file}.tmp" "$track_file"
    fi
}

# Abstract functions (to be overridden by adapters)
adapter_install() { os_log_error "adapter_install not implemented"; return 1; }
adapter_start() { os_log_error "adapter_start not implemented"; return 1; }
adapter_stop() { os_log_error "adapter_stop not implemented"; return 1; }
adapter_status() { os_log_error "adapter_status not implemented"; return 1; }
adapter_logs() { os_log_error "adapter_logs not implemented"; return 1; }
adapter_backup() { os_log_error "adapter_backup not implemented"; return 1; }
adapter_restore() { os_log_error "adapter_restore not implemented"; return 1; }
adapter_update() { os_log_error "adapter_update not implemented"; return 1; }
adapter_remove() { os_log_error "adapter_remove not implemented"; return 1; }
