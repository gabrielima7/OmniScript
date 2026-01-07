#!/usr/bin/env bash
#===============================================================================
# OmniScript - Target Management Library
# Unified interface for deployment targets (Docker, Podman, LXC, Bare Metal)
#===============================================================================
# shellcheck disable=SC2034

#-------------------------------------------------------------------------------
# Target Variables
#-------------------------------------------------------------------------------
declare -ga OS_AVAILABLE_TARGETS=()
OS_CURRENT_TARGET=""
OS_DEFAULT_TARGET="auto"

# Target metadata
declare -gA OS_TARGET_NAMES=(
    [docker]="Docker"
    [podman]="Podman"
    [lxc]="LXC/LXD"
    [baremetal]="Bare Metal"
    [k8s]="Kubernetes"
)

declare -gA OS_TARGET_ICONS=(
    [docker]="${EMOJI_DOCKER}"
    [podman]="${EMOJI_PODMAN}"
    [lxc]="${EMOJI_LXC}"
    [baremetal]="${EMOJI_METAL}"
    [k8s]="☸️"
)

declare -gA OS_TARGET_DESCRIPTIONS=(
    [docker]="Docker containers with Compose"
    [podman]="Rootless containers"
    [lxc]="System containers (LXD)"
    [baremetal]="Native packages"
    [k8s]="Container Orchestration"
)

#-------------------------------------------------------------------------------
# Target Detection
#-------------------------------------------------------------------------------
os_detect_targets() {
    OS_AVAILABLE_TARGETS=()
    
    # Docker
    if command -v docker &> /dev/null && docker info &> /dev/null; then
        OS_AVAILABLE_TARGETS+=("docker")
        os_debug "Docker detected and running"
    fi
    
    # Podman
    if command -v podman &> /dev/null; then
        OS_AVAILABLE_TARGETS+=("podman")
        os_debug "Podman detected"
    fi
    
    # LXC/LXD
    if command -v lxc &> /dev/null && lxc list &> /dev/null 2>&1; then
        OS_AVAILABLE_TARGETS+=("lxc")
        os_debug "LXC/LXD detected and running"
    fi
    
    # Bare Metal is always available
    OS_AVAILABLE_TARGETS+=("baremetal")
    
    # K8s Detection
    if os_target_check_k8s; then
        OS_AVAILABLE_TARGETS+=("k8s")
    fi
    
    # Set default target
    if [[ "${OS_DEFAULT_TARGET}" == "auto" ]]; then
        if os_array_contains "docker" "${OS_AVAILABLE_TARGETS[@]}"; then
            OS_CURRENT_TARGET="docker"
        elif os_array_contains "podman" "${OS_AVAILABLE_TARGETS[@]}"; then
            OS_CURRENT_TARGET="podman"
        else
            OS_CURRENT_TARGET="baremetal"
        fi
    else
        OS_CURRENT_TARGET="${OS_DEFAULT_TARGET}"
    fi
    
    os_debug "Current target: ${OS_CURRENT_TARGET}"
}

os_is_target_available() {
    local target="$1"
    os_array_contains "$target" "${OS_AVAILABLE_TARGETS[@]}"
}

os_set_target() {
    local target="$1"
    
    if ! os_is_target_available "$target"; then
        os_error "Target not available: ${target}"
        return 1
    fi
    
    OS_CURRENT_TARGET="$target"
    os_config_set "OS_DEFAULT_TARGET" "$target"
    os_info "Target set to: ${OS_TARGET_NAMES[$target]}"
}

os_select_target() {
    local options=()
    
    for target in "${OS_AVAILABLE_TARGETS[@]}"; do
        options+=("${OS_TARGET_ICONS[$target]} ${OS_TARGET_NAMES[$target]} - ${OS_TARGET_DESCRIPTIONS[$target]}")
    done
    
    os_menu_header "Select Deployment Target"
    os_select "Choose target" "${options[@]}"
    
    if [[ $? -eq 0 ]]; then
        OS_CURRENT_TARGET="${OS_AVAILABLE_TARGETS[$OS_SELECTED_INDEX]}"
        os_config_set "OS_DEFAULT_TARGET" "${OS_CURRENT_TARGET}"
        return 0
    fi
    
    return 1
}

#-------------------------------------------------------------------------------
# Target Adapter Loading
#-------------------------------------------------------------------------------
os_load_target_adapter() {
    local target="${1:-$OS_CURRENT_TARGET}"
    local adapter_file="${OS_LIB_DIR}/targets/${target}.sh"
    
    if [[ -f "$adapter_file" ]]; then
        # shellcheck source=/dev/null
        source "$adapter_file"
        os_debug "Loaded target adapter: ${target}"
        return 0
    else
        os_error "Target adapter not found: ${adapter_file}"
        return 1
    fi
}

#-------------------------------------------------------------------------------
# Unified Target Interface
# These functions delegate to the loaded target adapter
#-------------------------------------------------------------------------------

# Deploy a module to the current target
os_target_deploy() {
    local module_name="$1"
    shift
    
    os_load_target_adapter
    
    case "${OS_CURRENT_TARGET}" in
        docker)  os_docker_deploy "$module_name" "$@" ;;
        podman)  os_podman_deploy "$module_name" "$@" ;;
        lxc)     os_lxc_deploy "$module_name" "$@" ;;
        baremetal) os_baremetal_deploy "$module_name" "$@" ;;
        k8s)     os_k8s_deploy "$module_name" "$@" ;;
        *) os_fatal "Unknown target: ${OS_CURRENT_TARGET}" ;;
    esac
}

# Remove a deployment
os_target_remove() {
    local deployment_name="$1"
    
    os_load_target_adapter
    
    case "${OS_CURRENT_TARGET}" in
        docker)  os_docker_remove "$deployment_name" ;;
        podman)  os_podman_remove "$deployment_name" ;;
        lxc)     os_lxc_remove "$deployment_name" ;;
        baremetal) os_baremetal_remove "$deployment_name" ;;
        k8s)     os_k8s_remove "$deployment_name" ;;
        *) os_fatal "Unknown target: ${OS_CURRENT_TARGET}" ;;
    esac
}

# List deployments
os_target_list() {
    os_load_target_adapter
    
    case "${OS_CURRENT_TARGET}" in
        docker)  os_docker_list ;;
        podman)  os_podman_list ;;
        lxc)     os_lxc_list ;;
        baremetal) os_baremetal_list ;;
        k8s)     os_k8s_list ;;
        *) os_fatal "Unknown target: ${OS_CURRENT_TARGET}" ;;
    esac
}

# Get deployment status
os_target_status() {
    local deployment_name="$1"
    
    os_load_target_adapter
    
    case "${OS_CURRENT_TARGET}" in
        docker)  os_docker_status "$deployment_name" ;;
        podman)  os_podman_status "$deployment_name" ;;
        lxc)     os_lxc_status "$deployment_name" ;;
        baremetal) os_baremetal_status "$deployment_name" ;;
        k8s)     os_k8s_status "$deployment_name" ;;
        *) os_fatal "Unknown target: ${OS_CURRENT_TARGET}" ;;
    esac
}

# Start a deployment
os_target_start() {
    local deployment_name="$1"
    
    os_load_target_adapter
    
    case "${OS_CURRENT_TARGET}" in
        docker)  os_docker_start "$deployment_name" ;;
        podman)  os_podman_start "$deployment_name" ;;
        lxc)     os_lxc_start "$deployment_name" ;;
        baremetal) os_baremetal_start "$deployment_name" ;;
        k8s)     os_k8s_start "$deployment_name" ;;
        *) os_fatal "Unknown target: ${OS_CURRENT_TARGET}" ;;
    esac
}

# Stop a deployment
os_target_stop() {
    local deployment_name="$1"
    
    os_load_target_adapter
    
    case "${OS_CURRENT_TARGET}" in
        docker)  os_docker_stop "$deployment_name" ;;
        podman)  os_podman_stop "$deployment_name" ;;
        lxc)     os_lxc_stop "$deployment_name" ;;
        baremetal) os_baremetal_stop "$deployment_name" ;;
        k8s)     os_k8s_stop "$deployment_name" ;;
        *) os_fatal "Unknown target: ${OS_CURRENT_TARGET}" ;;
    esac
}

# Restart a deployment
os_target_restart() {
    local deployment_name="$1"
    
    os_load_target_adapter
    
    case "${OS_CURRENT_TARGET}" in
        docker)  os_docker_restart "$deployment_name" ;;
        podman)  os_podman_restart "$deployment_name" ;;
        lxc)     os_lxc_restart "$deployment_name" ;;
        baremetal) os_baremetal_restart "$deployment_name" ;;
        k8s)     os_k8s_restart "$deployment_name" ;;
        *) os_fatal "Unknown target: ${OS_CURRENT_TARGET}" ;;
    esac
}

# View logs
os_target_logs() {
    local deployment_name="$1"
    local lines="${2:-100}"
    
    os_load_target_adapter
    
    case "${OS_CURRENT_TARGET}" in
        docker)  os_docker_logs "$deployment_name" "$lines" ;;
        podman)  os_podman_logs "$deployment_name" "$lines" ;;
        lxc)     os_lxc_logs "$deployment_name" "$lines" ;;
        baremetal) os_baremetal_logs "$deployment_name" "$lines" ;;
        k8s)     os_k8s_logs "$deployment_name" "$lines" ;;
        *) os_fatal "Unknown target: ${OS_CURRENT_TARGET}" ;;
    esac
}

# Execute command in deployment
os_target_exec() {
    local deployment_name="$1"
    shift
    
    os_load_target_adapter
    
    case "${OS_CURRENT_TARGET}" in
        docker)  os_docker_exec "$deployment_name" "$@" ;;
        podman)  os_podman_exec "$deployment_name" "$@" ;;
        lxc)     os_lxc_exec "$deployment_name" "$@" ;;
        baremetal) os_baremetal_exec "$deployment_name" "$@" ;;
        k8s)     os_k8s_exec "$deployment_name" "$@" ;;
        *) os_fatal "Unknown target: ${OS_CURRENT_TARGET}" ;;
    esac
}

# Backup deployment
os_target_backup() {
    local deployment_name="$1"
    local backup_path="${2:-}"
    
    os_load_target_adapter
    
    case "${OS_CURRENT_TARGET}" in
        docker)  os_docker_backup "$deployment_name" "$backup_path" ;;
        podman)  os_podman_backup "$deployment_name" "$backup_path" ;;
        lxc)     os_lxc_backup "$deployment_name" "$backup_path" ;;
        baremetal) os_baremetal_backup "$deployment_name" "$backup_path" ;;
        k8s)     os_k8s_backup "$deployment_name" "$backup_path" ;;
        *) os_fatal "Unknown target: ${OS_CURRENT_TARGET}" ;;
    esac
}

# Restore deployment
os_target_restore() {
    local backup_path="$1"
    local deployment_name="${2:-}"
    
    os_load_target_adapter
    
    case "${OS_CURRENT_TARGET}" in
        docker)  os_docker_restore "$backup_path" "$deployment_name" ;;
        podman)  os_podman_restore "$backup_path" "$deployment_name" ;;
        lxc)     os_lxc_restore "$backup_path" "$deployment_name" ;;
        baremetal) os_baremetal_restore "$backup_path" "$deployment_name" ;;
        k8s)     os_k8s_restore "$backup_path" "$deployment_name" ;;
        *) os_fatal "Unknown target: ${OS_CURRENT_TARGET}" ;;
    esac
}

# Update deployment (zero-downtime)
os_target_update() {
    local deployment_name="$1"
    
    os_load_target_adapter
    
    case "${OS_CURRENT_TARGET}" in
        docker)  os_docker_update "$deployment_name" ;;
        podman)  os_podman_update "$deployment_name" ;;
        lxc)     os_lxc_update "$deployment_name" ;;
        baremetal) os_baremetal_update "$deployment_name" ;;
        k8s)     os_k8s_update "$deployment_name" ;;
        *) os_fatal "Unknown target: ${OS_CURRENT_TARGET}" ;;
    esac
}

#-------------------------------------------------------------------------------
# Target Info Display
#-------------------------------------------------------------------------------
os_show_target_info() {
    echo ""
    echo -e "  ${C_BOLD}Current Target:${C_RESET} ${OS_TARGET_ICONS[$OS_CURRENT_TARGET]} ${OS_TARGET_NAMES[$OS_CURRENT_TARGET]}"
    echo -e "  ${C_BOLD}Available Targets:${C_RESET}"
    
    for target in "${OS_AVAILABLE_TARGETS[@]}"; do
        local status="${C_GREEN}●${C_RESET}"
        [[ "$target" == "$OS_CURRENT_TARGET" ]] && status="${C_CYAN}◆${C_RESET}"
        echo -e "    ${status} ${OS_TARGET_ICONS[$target]} ${OS_TARGET_NAMES[$target]}"
    done
    echo ""
}

#-------------------------------------------------------------------------------
# Initialization Flag
#-------------------------------------------------------------------------------
OS_TARGETS_LOADED=true
