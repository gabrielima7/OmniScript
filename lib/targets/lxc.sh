#!/usr/bin/env bash
#===============================================================================
# OmniScript - LXC/LXD Target Adapter
# System container management with LXD
#===============================================================================
# shellcheck disable=SC2034

#-------------------------------------------------------------------------------
# LXC Configuration
#-------------------------------------------------------------------------------
OS_LXC_DATA_DIR="${OS_DATA_DIR}/lxc"
OS_LXC_PROFILES_DIR="${OS_LXC_DATA_DIR}/profiles"

#-------------------------------------------------------------------------------
# LXC Availability Check
#-------------------------------------------------------------------------------
os_lxc_check() {
    if ! command -v lxc &> /dev/null; then
        os_error "LXC/LXD is not installed"
        return 1
    fi
    
    if ! lxc list &> /dev/null 2>&1; then
        os_error "LXD is not initialized or user lacks permissions"
        os_info "Try: lxd init"
        return 1
    fi
    
    return 0
}

#-------------------------------------------------------------------------------
# Container Lifecycle
#-------------------------------------------------------------------------------
os_lxc_deploy() {
    local module_name="$1"
    shift
    local args=("$@")
    
    os_lxc_check || return 1
    
    local container_name="${module_name}"
    local image="${OS_LXC_DEFAULT_IMAGE:-ubuntu:22.04}"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --image) image="$2"; shift 2 ;;
            --name) container_name="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    os_info "Deploying ${module_name} with LXC..."
    
    # Create container
    if lxc info "$container_name" &> /dev/null; then
        os_warn "Container ${container_name} already exists"
    else
        lxc launch "$image" "$container_name"
    fi
    
    # Wait for container to be ready
    os_task_start "Waiting for container"
    local retries=30
    while [[ $retries -gt 0 ]]; do
        if lxc exec "$container_name" -- sh -c "echo ready" &> /dev/null; then
            break
        fi
        sleep 1
        ((retries--))
    done
    os_task_done "Container ready"
    
    # Find and run module installer
    local module_file
    module_file=$(find "${OS_MODULES_DIR}" -name "${module_name}.sh" 2>/dev/null | head -1)
    
    if [[ -n "$module_file" ]]; then
        # shellcheck source=/dev/null
        source "$module_file"
        
        if declare -f os_module_lxc > /dev/null; then
            os_module_lxc "$container_name"
        elif declare -f os_module_baremetal > /dev/null; then
            # Push module script and run inside container
            lxc file push "$module_file" "${container_name}/tmp/module.sh"
            lxc exec "$container_name" -- bash /tmp/module.sh baremetal
        fi
    fi
    
    os_success "Deployed ${module_name} in ${container_name}"
}

os_lxc_remove() {
    local deployment_name="$1"
    
    os_lxc_check || return 1
    
    if ! lxc info "$deployment_name" &> /dev/null; then
        os_error "Container not found: ${deployment_name}"
        return 1
    fi
    
    os_info "Removing ${deployment_name}..."
    
    lxc stop "$deployment_name" --force 2>/dev/null || true
    lxc delete "$deployment_name"
    
    os_success "Removed ${deployment_name}"
}

os_lxc_start() {
    local deployment_name="$1"
    
    os_lxc_check || return 1
    lxc start "$deployment_name"
}

os_lxc_stop() {
    local deployment_name="$1"
    
    os_lxc_check || return 1
    lxc stop "$deployment_name"
}

os_lxc_restart() {
    local deployment_name="$1"
    
    os_lxc_check || return 1
    lxc restart "$deployment_name"
}

#-------------------------------------------------------------------------------
# Status & Info
#-------------------------------------------------------------------------------
os_lxc_list() {
    os_lxc_check || return 1
    
    os_menu_header "LXC Containers"
    lxc list --format table
}

os_lxc_status() {
    local deployment_name="$1"
    
    os_lxc_check || return 1
    lxc info "$deployment_name"
}

os_lxc_logs() {
    local deployment_name="$1"
    local lines="${2:-100}"
    
    os_lxc_check || return 1
    
    # Try to get console log
    lxc console "$deployment_name" --show-log 2>/dev/null | tail -n "$lines" ||
        lxc exec "$deployment_name" -- journalctl -n "$lines" --no-pager 2>/dev/null ||
        lxc exec "$deployment_name" -- tail -n "$lines" /var/log/syslog 2>/dev/null
}

os_lxc_exec() {
    local deployment_name="$1"
    shift
    local cmd=("$@")
    
    os_lxc_check || return 1
    
    if [[ ${#cmd[@]} -eq 0 ]]; then
        lxc exec "$deployment_name" -- /bin/bash
    else
        lxc exec "$deployment_name" -- "${cmd[@]}"
    fi
}

#-------------------------------------------------------------------------------
# Backup & Restore
#-------------------------------------------------------------------------------
os_lxc_backup() {
    local deployment_name="$1"
    local backup_path="${2:-${OS_DATA_DIR}/backups}"
    
    os_lxc_check || return 1
    
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local snapshot_name="backup-${timestamp}"
    local backup_file="${backup_path}/${deployment_name}_lxc_${timestamp}.tar.gz"
    
    mkdir -p "$backup_path"
    
    os_info "Backing up ${deployment_name}..."
    
    # Create snapshot
    lxc snapshot "$deployment_name" "$snapshot_name"
    
    # Export container
    lxc export "$deployment_name" "$backup_file" --instance-only
    
    # Remove snapshot
    lxc delete "${deployment_name}/${snapshot_name}"
    
    os_success "Backup created: ${backup_file}"
    echo "$backup_file"
}

os_lxc_restore() {
    local backup_path="$1"
    local deployment_name="${2:-}"
    
    os_lxc_check || return 1
    
    if [[ ! -f "$backup_path" ]]; then
        os_error "Backup file not found: ${backup_path}"
        return 1
    fi
    
    os_info "Restoring from ${backup_path}..."
    
    if [[ -z "$deployment_name" ]]; then
        deployment_name=$(basename "$backup_path" | sed 's/_lxc_.*//')
    fi
    
    # Import container
    lxc import "$backup_path" "$deployment_name"
    
    # Start container
    lxc start "$deployment_name"
    
    os_success "Restored ${deployment_name}"
}

#-------------------------------------------------------------------------------
# Update
#-------------------------------------------------------------------------------
os_lxc_update() {
    local deployment_name="$1"
    
    os_lxc_check || return 1
    
    if ! lxc info "$deployment_name" &> /dev/null; then
        os_error "Container not found: ${deployment_name}"
        return 1
    fi
    
    os_info "Updating ${deployment_name}..."
    
    # Update packages inside container
    lxc exec "$deployment_name" -- sh -c "
        if command -v apt &> /dev/null; then
            apt update && apt upgrade -y
        elif command -v dnf &> /dev/null; then
            dnf upgrade -y
        elif command -v apk &> /dev/null; then
            apk update && apk upgrade
        fi
    "
    
    os_success "Updated ${deployment_name}"
}

#-------------------------------------------------------------------------------
# Profiles
#-------------------------------------------------------------------------------
os_lxc_create_profile() {
    local name="$1"
    local config="$2"
    
    os_lxc_check || return 1
    
    mkdir -p "${OS_LXC_PROFILES_DIR}"
    
    echo "$config" > "${OS_LXC_PROFILES_DIR}/${name}.yaml"
    lxc profile create "$name" 2>/dev/null || true
    lxc profile edit "$name" < "${OS_LXC_PROFILES_DIR}/${name}.yaml"
}

os_lxc_apply_profile() {
    local container="$1"
    local profile="$2"
    
    os_lxc_check || return 1
    lxc profile add "$container" "$profile"
}

#-------------------------------------------------------------------------------
# Port Forwarding
#-------------------------------------------------------------------------------
os_lxc_forward_port() {
    local container="$1"
    local host_port="$2"
    local container_port="${3:-$host_port}"
    
    os_lxc_check || return 1
    
    # Get container IP
    local container_ip
    container_ip=$(lxc list "$container" --format csv -c 4 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    
    if [[ -z "$container_ip" ]]; then
        os_error "Could not get container IP"
        return 1
    fi
    
    # Add proxy device for port forwarding
    lxc config device add "$container" "port${host_port}" proxy \
        listen="tcp:0.0.0.0:${host_port}" \
        connect="tcp:${container_ip}:${container_port}"
    
    os_success "Forwarded port ${host_port} -> ${container}:${container_port}"
}

#-------------------------------------------------------------------------------
# Resource Limits
#-------------------------------------------------------------------------------
os_lxc_set_limits() {
    local container="$1"
    local cpu="${2:-}"
    local memory="${3:-}"
    local disk="${4:-}"
    
    os_lxc_check || return 1
    
    if [[ -n "$cpu" ]]; then
        lxc config set "$container" limits.cpu "$cpu"
    fi
    
    if [[ -n "$memory" ]]; then
        lxc config set "$container" limits.memory "$memory"
    fi
    
    if [[ -n "$disk" ]]; then
        lxc config device set "$container" root size="$disk"
    fi
    
    os_success "Set resource limits for ${container}"
}

#-------------------------------------------------------------------------------
# Initialization Flag
#-------------------------------------------------------------------------------
OS_LXC_ADAPTER_LOADED=true
