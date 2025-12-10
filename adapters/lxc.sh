#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  OmniScript - LXC/LXD Adapter                                              ║
# ║  Deploy applications using LXC containers                                  ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

[[ -n "${_OS_ADAPTER_LXC_LOADED:-}" ]] && return 0
readonly _OS_ADAPTER_LXC_LOADED=1

source "${OS_ADAPTERS_DIR}/base.sh"

ADAPTER_NAME="lxc"
ADAPTER_TYPE="container"

lxc_is_available() {
    command -v lxc &>/dev/null && lxc list &>/dev/null 2>&1
}

lxc_get_latest_image() {
    local image="${1:-images:debian/bookworm}"
    
    # Query images.linuxcontainers.org
    local base_image="${image#images:}"
    local distro="${base_image%%/*}"
    
    # Get available images
    local available
    available=$(lxc image list images: "${distro}" -c l --format csv 2>/dev/null | head -5)
    
    if [[ -n "$available" ]]; then
        echo "images:${available%%,*}"
    else
        echo "$image"
    fi
}

lxc_create_profile() {
    local app_name="$1"
    local profile_name="os-${app_name}"
    
    # Check if profile exists
    if lxc profile show "$profile_name" &>/dev/null; then
        return 0
    fi
    
    # Create profile with resources
    lxc profile create "$profile_name" 2>/dev/null || true
    
    # Apply limits if defined
    local cpu_limit="${APP_CPU_LIMIT:-2}"
    local mem_limit="${APP_MEM_LIMIT:-1GB}"
    
    lxc profile set "$profile_name" limits.cpu "$cpu_limit"
    lxc profile set "$profile_name" limits.memory "$mem_limit"
    
    echo "$profile_name"
}

adapter_install() {
    if ! lxc_is_available; then
        os_log_error "LXC/LXD is not available"
        return 1
    fi
    
    local app_name="${APP_NAME:-}"
    local container_name="os-${app_name}"
    local image="${LXC_IMAGE:-images:debian/bookworm}"
    
    os_log_step 1 4 "Getting latest image..."
    image=$(lxc_get_latest_image "$image")
    os_log_info "Using image: $image"
    
    os_log_step 2 4 "Creating container..."
    os_spinner_start "Creating $container_name..."
    lxc launch "$image" "$container_name" &>/dev/null
    os_spinner_stop
    
    os_log_step 3 4 "Configuring container..."
    
    # Wait for container to be ready
    sleep 3
    
    # Apply resource limits
    local cpu_limit="${APP_CPU_LIMIT:-2}"
    local mem_limit="${APP_MEM_LIMIT:-1GB}"
    lxc config set "$container_name" limits.cpu "$cpu_limit"
    lxc config set "$container_name" limits.memory "$mem_limit"
    
    # Configure ports (proxy devices)
    for port in "${PORTS[@]:-}"; do
        lxc config device add "$container_name" "port${port}" proxy \
            listen="tcp:0.0.0.0:${port}" connect="tcp:127.0.0.1:${port}" 2>/dev/null || true
    done
    
    os_log_step 4 4 "Installing packages..."
    
    # Detect OS inside container and install packages
    local pkg_cmd
    if lxc exec "$container_name" -- which apt &>/dev/null; then
        pkg_cmd="apt-get update && apt-get install -y"
    elif lxc exec "$container_name" -- which apk &>/dev/null; then
        pkg_cmd="apk add"
    elif lxc exec "$container_name" -- which dnf &>/dev/null; then
        pkg_cmd="dnf install -y"
    fi
    
    # Install app packages
    local packages="${APT_PACKAGES:-${DNF_PACKAGES:-${APK_PACKAGES:-}}}"
    if [[ -n "$packages" && -n "$pkg_cmd" ]]; then
        os_spinner_start "Installing $packages..."
        lxc exec "$container_name" -- bash -c "$pkg_cmd $packages" &>/dev/null
        os_spinner_stop
    fi
    
    os_track_installation "$app_name" "lxc" "$container_name"
    os_log_success "Container created: $container_name"
    
    # Show access info
    local ip
    ip=$(lxc list "$container_name" -c 4 --format csv | cut -d' ' -f1)
    [[ -n "$ip" ]] && os_log_info "Container IP: $ip"
}

adapter_start() {
    lxc start "os-${APP_NAME:-}" && os_log_success "Started ${APP_NAME:-}"
}

adapter_stop() {
    lxc stop "os-${APP_NAME:-}" && os_log_success "Stopped ${APP_NAME:-}"
}

adapter_status() {
    lxc list "os-${APP_NAME:-}" -c ns4
}

adapter_logs() {
    lxc exec "os-${APP_NAME:-}" -- journalctl -n "${1:-100}" -f 2>/dev/null || \
    lxc exec "os-${APP_NAME:-}" -- tail -f /var/log/syslog
}

adapter_backup() {
    local app_name="${APP_NAME:-}"
    local container_name="os-${app_name}"
    local backup_dir="${OS_CONFIG[BACKUP_DIR]:-/var/backups/omniscript}"
    local timestamp; timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${backup_dir}/${app_name}_lxc_${timestamp}"
    
    os_ensure_dir "$backup_dir"
    
    os_log_info "Creating snapshot..."
    lxc snapshot "$container_name" "backup-${timestamp}"
    
    os_log_info "Exporting..."
    lxc export "$container_name" "${backup_file}.tar.gz" --optimized-storage
    
    os_log_success "Backup: ${backup_file}.tar.gz"
}

adapter_restore() {
    local backup_file="$1"
    local app_name; app_name=$(basename "$backup_file" | sed 's/_lxc_.*//')
    
    os_log_info "Importing container..."
    lxc import "$backup_file" "os-${app_name}-restored"
    lxc start "os-${app_name}-restored"
    
    os_log_success "Restored as os-${app_name}-restored"
}

adapter_update() {
    local app_name="${APP_NAME:-}"
    local container_name="os-${app_name}"
    
    os_log_info "Updating packages inside container..."
    
    if lxc exec "$container_name" -- which apt &>/dev/null; then
        lxc exec "$container_name" -- apt-get update
        lxc exec "$container_name" -- apt-get upgrade -y
    elif lxc exec "$container_name" -- which apk &>/dev/null; then
        lxc exec "$container_name" -- apk upgrade
    elif lxc exec "$container_name" -- which dnf &>/dev/null; then
        lxc exec "$container_name" -- dnf upgrade -y
    fi
    
    os_log_success "Updated packages in $container_name"
}

adapter_remove() {
    local container_name="os-${APP_NAME:-}"
    
    if os_confirm "Remove $container_name?"; then
        lxc stop "$container_name" --force 2>/dev/null
        lxc delete "$container_name"
        os_untrack_installation "${APP_NAME:-}"
        os_log_success "Removed $container_name"
    fi
}
