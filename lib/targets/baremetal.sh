#!/usr/bin/env bash
#===============================================================================
# OmniScript - Bare Metal Target Adapter
# Native package installation and service management
#===============================================================================
# shellcheck disable=SC2034

#-------------------------------------------------------------------------------
# Bare Metal Configuration
#-------------------------------------------------------------------------------
OS_BAREMETAL_DATA_DIR="${OS_DATA_DIR}/baremetal"
OS_BAREMETAL_DEPLOY_DIR="${OS_BAREMETAL_DATA_DIR}/deployments"

#-------------------------------------------------------------------------------
# Deployment Registry
#-------------------------------------------------------------------------------
# Track what we've deployed for management
os_baremetal_register() {
    local name="$1"
    local type="$2"  # package, service, config
    local details="$3"
    
    mkdir -p "${OS_BAREMETAL_DEPLOY_DIR}"
    
    local registry_file="${OS_BAREMETAL_DEPLOY_DIR}/${name}.json"
    
    cat > "$registry_file" << EOF
{
    "name": "${name}",
    "type": "${type}",
    "details": "${details}",
    "installed_at": "$(date -Iseconds)",
    "distro": "${OS_DISTRO_ID}",
    "packages": []
}
EOF
}

os_baremetal_add_package() {
    local deployment="$1"
    local package="$2"
    
    local registry_file="${OS_BAREMETAL_DEPLOY_DIR}/${deployment}.json"
    
    if [[ -f "$registry_file" ]] && command -v jq &> /dev/null; then
        local temp_file
        temp_file=$(mktemp)
        jq ".packages += [\"${package}\"]" "$registry_file" > "$temp_file"
        mv "$temp_file" "$registry_file"
    fi
}

#-------------------------------------------------------------------------------
# Deployment Operations
#-------------------------------------------------------------------------------
os_baremetal_deploy() {
    local module_name="$1"
    shift
    local args=("$@")
    
    os_info "Deploying ${module_name} natively..."
    
    # Find and load module
    local module_file
    module_file=$(find "${OS_MODULES_DIR}" -name "${module_name}.sh" 2>/dev/null | head -1)
    
    if [[ -z "$module_file" ]]; then
        os_error "Module not found: ${module_name}"
        return 1
    fi
    
    # shellcheck source=/dev/null
    source "$module_file"
    
    # Check if module supports bare metal
    if ! declare -f os_module_baremetal > /dev/null; then
        os_error "Module ${module_name} does not support bare metal deployment"
        return 1
    fi
    
    # Register deployment
    os_baremetal_register "$module_name" "module" "Native installation"
    
    # Run module's bare metal installer
    os_module_baremetal "${args[@]}"
    
    os_success "Deployed ${module_name} natively"
}

os_baremetal_remove() {
    local deployment_name="$1"
    
    local registry_file="${OS_BAREMETAL_DEPLOY_DIR}/${deployment_name}.json"
    
    if [[ ! -f "$registry_file" ]]; then
        os_error "Deployment not found: ${deployment_name}"
        return 1
    fi
    
    os_info "Removing ${deployment_name}..."
    
    # Get installed packages
    if command -v jq &> /dev/null; then
        local packages
        packages=$(jq -r '.packages[]' "$registry_file" 2>/dev/null)
        
        for package in $packages; do
            os_pkg_remove "$package"
        done
    fi
    
    # Find and run module's uninstall
    local module_file
    module_file=$(find "${OS_MODULES_DIR}" -name "${deployment_name}.sh" 2>/dev/null | head -1)
    
    if [[ -n "$module_file" ]]; then
        # shellcheck source=/dev/null
        source "$module_file"
        
        if declare -f os_module_uninstall > /dev/null; then
            os_module_uninstall
        fi
    fi
    
    rm -f "$registry_file"
    
    os_success "Removed ${deployment_name}"
}

os_baremetal_start() {
    local deployment_name="$1"
    
    local registry_file="${OS_BAREMETAL_DEPLOY_DIR}/${deployment_name}.json"
    
    if [[ ! -f "$registry_file" ]]; then
        # Try as service name directly
        os_service_start "$deployment_name"
        return
    fi
    
    # Find module and get service name
    local module_file
    module_file=$(find "${OS_MODULES_DIR}" -name "${deployment_name}.sh" 2>/dev/null | head -1)
    
    if [[ -n "$module_file" ]]; then
        # shellcheck source=/dev/null
        source "$module_file"
        
        if [[ -n "${OS_MODULE_SERVICE:-}" ]]; then
            os_service_start "${OS_MODULE_SERVICE}"
        fi
    fi
}

os_baremetal_stop() {
    local deployment_name="$1"
    
    local registry_file="${OS_BAREMETAL_DEPLOY_DIR}/${deployment_name}.json"
    
    if [[ ! -f "$registry_file" ]]; then
        os_service_stop "$deployment_name"
        return
    fi
    
    local module_file
    module_file=$(find "${OS_MODULES_DIR}" -name "${deployment_name}.sh" 2>/dev/null | head -1)
    
    if [[ -n "$module_file" ]]; then
        # shellcheck source=/dev/null
        source "$module_file"
        
        if [[ -n "${OS_MODULE_SERVICE:-}" ]]; then
            os_service_stop "${OS_MODULE_SERVICE}"
        fi
    fi
}

os_baremetal_restart() {
    local deployment_name="$1"
    
    os_baremetal_stop "$deployment_name"
    sleep 1
    os_baremetal_start "$deployment_name"
}

#-------------------------------------------------------------------------------
# Status & Listing
#-------------------------------------------------------------------------------
os_baremetal_list() {
    os_menu_header "Bare Metal Deployments"
    
    if [[ ! -d "${OS_BAREMETAL_DEPLOY_DIR}" ]]; then
        echo "  No deployments found"
        return
    fi
    
    for registry_file in "${OS_BAREMETAL_DEPLOY_DIR}"/*.json; do
        if [[ -f "$registry_file" ]]; then
            local name
            name=$(basename "$registry_file" .json)
            
            local status
            status=$(os_baremetal_status "$name" 2>/dev/null || echo "unknown")
            
            local status_color="${C_DIM}"
            case "$status" in
                running|active) status_color="${C_GREEN}" ;;
                stopped|inactive) status_color="${C_RED}" ;;
                *) status_color="${C_YELLOW}" ;;
            esac
            
            echo -e "  ${EMOJI_METAL} ${name} - ${status_color}${status}${C_RESET}"
        fi
    done
}

os_baremetal_status() {
    local deployment_name="$1"
    
    local module_file
    module_file=$(find "${OS_MODULES_DIR}" -name "${deployment_name}.sh" 2>/dev/null | head -1)
    
    if [[ -n "$module_file" ]]; then
        # shellcheck source=/dev/null
        source "$module_file"
        
        if [[ -n "${OS_MODULE_SERVICE:-}" ]]; then
            os_service_status "${OS_MODULE_SERVICE}"
            return
        fi
    fi
    
    # Try as service directly
    os_service_status "$deployment_name"
}

os_baremetal_logs() {
    local deployment_name="$1"
    local lines="${2:-100}"
    
    # Try journalctl first (systemd)
    if [[ "${OS_INIT_SYSTEM}" == "systemd" ]]; then
        local module_file
        module_file=$(find "${OS_MODULES_DIR}" -name "${deployment_name}.sh" 2>/dev/null | head -1)
        
        if [[ -n "$module_file" ]]; then
            # shellcheck source=/dev/null
            source "$module_file"
            
            if [[ -n "${OS_MODULE_SERVICE:-}" ]]; then
                journalctl -u "${OS_MODULE_SERVICE}" -n "$lines" --no-pager
                return
            fi
        fi
        
        journalctl -u "$deployment_name" -n "$lines" --no-pager
    else
        # Try common log locations
        local log_files=(
            "/var/log/${deployment_name}/${deployment_name}.log"
            "/var/log/${deployment_name}.log"
            "/var/log/${deployment_name}/error.log"
        )
        
        for log_file in "${log_files[@]}"; do
            if [[ -f "$log_file" ]]; then
                tail -n "$lines" "$log_file"
                return
            fi
        done
        
        os_warn "No log files found for ${deployment_name}"
    fi
}

os_baremetal_exec() {
    local deployment_name="$1"
    shift
    local cmd=("$@")
    
    # For bare metal, just run the command
    if [[ ${#cmd[@]} -eq 0 ]]; then
        os_error "No command specified"
        return 1
    fi
    
    "${cmd[@]}"
}

#-------------------------------------------------------------------------------
# Backup & Restore
#-------------------------------------------------------------------------------
os_baremetal_backup() {
    local deployment_name="$1"
    local backup_path="${2:-${OS_DATA_DIR}/backups}"
    
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_file="${backup_path}/${deployment_name}_baremetal_${timestamp}.tar.gz"
    
    mkdir -p "$backup_path"
    
    os_info "Backing up ${deployment_name}..."
    
    # Stop service for consistent backup
    os_baremetal_stop "$deployment_name" 2>/dev/null || true
    
    # Find module and get data directories
    local module_file
    module_file=$(find "${OS_MODULES_DIR}" -name "${deployment_name}.sh" 2>/dev/null | head -1)
    
    local backup_dirs=()
    
    if [[ -n "$module_file" ]]; then
        # shellcheck source=/dev/null
        source "$module_file"
        
        if [[ -n "${OS_MODULE_DATA_DIRS:-}" ]]; then
            IFS=',' read -ra backup_dirs <<< "${OS_MODULE_DATA_DIRS}"
        fi
        
        if [[ -n "${OS_MODULE_CONFIG_FILES:-}" ]]; then
            IFS=',' read -ra config_files <<< "${OS_MODULE_CONFIG_FILES}"
            backup_dirs+=("${config_files[@]}")
        fi
    fi
    
    # Default directories if none specified
    if [[ ${#backup_dirs[@]} -eq 0 ]]; then
        backup_dirs=(
            "/etc/${deployment_name}"
            "/var/lib/${deployment_name}"
            "/var/log/${deployment_name}"
        )
    fi
    
    # Create backup
    local existing_dirs=()
    for dir in "${backup_dirs[@]}"; do
        if [[ -e "$dir" ]]; then
            existing_dirs+=("$dir")
        fi
    done
    
    if [[ ${#existing_dirs[@]} -gt 0 ]]; then
        tar -czf "$backup_file" "${existing_dirs[@]}" 2>/dev/null
        os_success "Backup created: ${backup_file}"
    else
        os_warn "No data directories found to backup"
    fi
    
    # Restart service
    os_baremetal_start "$deployment_name" 2>/dev/null || true
    
    echo "$backup_file"
}

os_baremetal_restore() {
    local backup_path="$1"
    local deployment_name="${2:-}"
    
    if [[ ! -f "$backup_path" ]]; then
        os_error "Backup file not found: ${backup_path}"
        return 1
    fi
    
    os_info "Restoring from ${backup_path}..."
    
    # Stop service
    if [[ -n "$deployment_name" ]]; then
        os_baremetal_stop "$deployment_name" 2>/dev/null || true
    fi
    
    # Restore files
    tar -xzf "$backup_path" -C /
    
    # Restart service
    if [[ -n "$deployment_name" ]]; then
        os_baremetal_start "$deployment_name" 2>/dev/null || true
    fi
    
    os_success "Restore complete"
}

#-------------------------------------------------------------------------------
# Update
#-------------------------------------------------------------------------------
os_baremetal_update() {
    local deployment_name="$1"
    
    os_info "Updating ${deployment_name}..."
    
    # Update system packages
    local registry_file="${OS_BAREMETAL_DEPLOY_DIR}/${deployment_name}.json"
    
    if [[ -f "$registry_file" ]] && command -v jq &> /dev/null; then
        local packages
        packages=$(jq -r '.packages[]' "$registry_file" 2>/dev/null)
        
        for package in $packages; do
            os_pkg_install "$package"
        done
    fi
    
    # Restart service
    os_baremetal_restart "$deployment_name"
    
    os_success "Updated ${deployment_name}"
}

#-------------------------------------------------------------------------------
# Helper Functions
#-------------------------------------------------------------------------------
os_baremetal_install_packages() {
    local deployment_name="$1"
    shift
    local packages=("$@")
    
    for package in "${packages[@]}"; do
        os_pkg_install "$package"
        os_baremetal_add_package "$deployment_name" "$package"
    done
}

os_baremetal_configure_service() {
    local service="$1"
    local enable="${2:-true}"
    
    if [[ "$enable" == "true" ]]; then
        os_service_enable "$service"
        os_service_start "$service"
    fi
}

os_baremetal_create_user() {
    local username="$1"
    local home_dir="${2:-/var/lib/${username}}"
    local shell="${3:-/usr/sbin/nologin}"
    
    if ! id "$username" &> /dev/null; then
        os_run_sudo "useradd -r -m -d '${home_dir}' -s '${shell}' '${username}'"
    fi
}

os_baremetal_set_permissions() {
    local path="$1"
    local owner="$2"
    local mode="${3:-755}"
    
    os_run_sudo "chown -R '${owner}:${owner}' '${path}'"
    os_run_sudo "chmod -R '${mode}' '${path}'"
}

#-------------------------------------------------------------------------------
# Initialization Flag
#-------------------------------------------------------------------------------
OS_BAREMETAL_ADAPTER_LOADED=true
