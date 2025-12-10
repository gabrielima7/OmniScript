#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  OmniScript - Bare Metal Adapter                                           ║
# ║  Install applications directly on the host system                          ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

[[ -n "${_OS_ADAPTER_BAREMETAL_LOADED:-}" ]] && return 0
readonly _OS_ADAPTER_BAREMETAL_LOADED=1

source "${OS_ADAPTERS_DIR}/base.sh"

ADAPTER_NAME="baremetal"
ADAPTER_TYPE="native"

# Load appropriate package manager
baremetal_load_pkg_manager() {
    local pkg_adapter="${OS_PKG_DIR}/${OS_PKG_MANAGER}.sh"
    if [[ -f "$pkg_adapter" ]]; then
        source "$pkg_adapter"
    else
        os_log_error "Package manager adapter not found: ${OS_PKG_MANAGER}"
        return 1
    fi
}

# Get packages for current distro
baremetal_get_packages() {
    case "$OS_PKG_MANAGER" in
        apt)    echo "${APT_PACKAGES:-}" ;;
        dnf)    echo "${DNF_PACKAGES:-}" ;;
        apk)    echo "${APK_PACKAGES:-}" ;;
        pacman) echo "${PACMAN_PACKAGES:-}" ;;
        zypper) echo "${ZYPPER_PACKAGES:-}" ;;
        *)      echo "${APT_PACKAGES:-}" ;;
    esac
}

adapter_install() {
    os_require_root
    
    local app_name="${APP_NAME:-}"
    local packages
    packages=$(baremetal_get_packages)
    
    if [[ -z "$packages" ]]; then
        os_log_error "No packages defined for $app_name on ${OS_PKG_MANAGER}"
        return 1
    fi
    
    os_log_step 1 3 "Updating package index..."
    pkg_update
    
    os_log_step 2 3 "Installing packages: $packages"
    os_spinner_start "Installing..."
    pkg_install $packages
    os_spinner_stop
    
    os_log_step 3 3 "Configuring service..."
    
    # Enable and start systemd service if exists
    local service_name="${APP_SERVICE:-$app_name}"
    if systemctl list-unit-files | grep -q "^${service_name}"; then
        systemctl enable "$service_name"
        systemctl start "$service_name"
        os_log_success "Service $service_name enabled and started"
    fi
    
    os_track_installation "$app_name" "baremetal" "native"
    os_log_success "Installed $packages"
}

adapter_start() {
    local service="${APP_SERVICE:-${APP_NAME:-}}"
    os_sudo systemctl start "$service" && os_log_success "Started $service"
}

adapter_stop() {
    local service="${APP_SERVICE:-${APP_NAME:-}}"
    os_sudo systemctl stop "$service" && os_log_success "Stopped $service"
}

adapter_status() {
    local service="${APP_SERVICE:-${APP_NAME:-}}"
    systemctl status "$service" --no-pager
}

adapter_logs() {
    local service="${APP_SERVICE:-${APP_NAME:-}}"
    journalctl -u "$service" -n "${1:-100}" -f
}

adapter_backup() {
    local app_name="${APP_NAME:-}"
    local backup_dir="${OS_CONFIG[BACKUP_DIR]:-/var/backups/omniscript}"
    local timestamp; timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${backup_dir}/${app_name}_baremetal_${timestamp}.tar.gz"
    
    os_ensure_dir "$backup_dir"
    
    # Backup config directories
    local config_dirs=()
    [[ -d "/etc/${app_name}" ]] && config_dirs+=("/etc/${app_name}")
    [[ -d "/var/lib/${app_name}" ]] && config_dirs+=("/var/lib/${app_name}")
    [[ -d "/var/www/${app_name}" ]] && config_dirs+=("/var/www/${app_name}")
    
    if [[ ${#config_dirs[@]} -gt 0 ]]; then
        os_log_info "Backing up: ${config_dirs[*]}"
        tar -czf "$backup_file" "${config_dirs[@]}" 2>/dev/null
        os_log_success "Backup: $backup_file"
    else
        os_log_warn "No config directories found to backup"
    fi
}

adapter_restore() {
    local backup_file="$1"
    
    os_require_root
    
    if [[ ! -f "$backup_file" ]]; then
        os_log_error "Backup file not found"
        return 1
    fi
    
    os_log_info "Restoring from $backup_file..."
    tar -xzf "$backup_file" -C /
    
    # Restart service
    local app_name; app_name=$(basename "$backup_file" | sed 's/_baremetal_.*//')
    local service="${APP_SERVICE:-$app_name}"
    systemctl restart "$service" 2>/dev/null || true
    
    os_log_success "Restored $app_name"
}

adapter_update() {
    os_require_root
    
    local packages
    packages=$(baremetal_get_packages)
    
    os_log_info "Updating packages..."
    pkg_update
    pkg_upgrade $packages
    
    os_log_success "Updated packages"
}

adapter_remove() {
    local app_name="${APP_NAME:-}"
    local packages
    packages=$(baremetal_get_packages)
    
    if os_confirm "Remove $app_name ($packages)?"; then
        os_require_root
        
        # Stop service
        local service="${APP_SERVICE:-$app_name}"
        systemctl stop "$service" 2>/dev/null || true
        systemctl disable "$service" 2>/dev/null || true
        
        # Remove packages
        pkg_remove $packages
        
        os_untrack_installation "$app_name"
        os_log_success "Removed $app_name"
    fi
}

# Load package manager on source
baremetal_load_pkg_manager
