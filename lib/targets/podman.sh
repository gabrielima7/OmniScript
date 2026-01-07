#!/usr/bin/env bash
#===============================================================================
# OmniScript - Podman Target Adapter
# Rootless container management with systemd integration
#===============================================================================
# shellcheck disable=SC2034

#-------------------------------------------------------------------------------
# Podman Configuration
#-------------------------------------------------------------------------------
OS_PODMAN_DATA_DIR="${OS_DATA_DIR}/podman"
OS_PODMAN_STACKS_DIR="${OS_PODMAN_DATA_DIR}/stacks"

#-------------------------------------------------------------------------------
# Podman Availability Check
#-------------------------------------------------------------------------------
os_podman_check() {
    if ! command -v podman &> /dev/null; then
        os_error "Podman is not installed"
        return 1
    fi
    return 0
}

os_podman_compose_cmd() {
    if command -v podman-compose &> /dev/null; then
        echo "podman-compose"
    elif podman compose version &> /dev/null 2>&1; then
        echo "podman compose"
    else
        os_warn "Podman Compose not available, using podman run"
        return 1
    fi
}

#-------------------------------------------------------------------------------
# Container Lifecycle
#-------------------------------------------------------------------------------
os_podman_deploy() {
    local module_name="$1"
    shift
    local args=("$@")
    
    os_podman_check || return 1
    
    local stack_dir="${OS_PODMAN_STACKS_DIR}/${module_name}"
    local compose_file="${stack_dir}/docker-compose.yml"
    
    mkdir -p "$stack_dir"
    
    # Check if module provides compose file
    local module_compose="${OS_MODULES_DIR}/*/${module_name}.sh"
    # shellcheck disable=SC2086
    if compgen -G "$module_compose" > /dev/null; then
        local module_file
        module_file=$(ls $module_compose 2>/dev/null | head -1)
        
        # shellcheck source=/dev/null
        source "$module_file"
        
        if declare -f os_module_compose > /dev/null; then
            os_module_compose "${args[@]}" > "$compose_file"
        fi
    fi
    
    os_info "Deploying ${module_name} with Podman..."
    
    if [[ -f "$compose_file" ]]; then
        local compose_cmd
        if compose_cmd=$(os_podman_compose_cmd); then
            cd "$stack_dir" || return 1
            $compose_cmd pull
            $compose_cmd up -d
        else
            os_error "Podman compose not available"
            return 1
        fi
    else
        os_error "No compose file found for ${module_name}"
        return 1
    fi
    
    # Generate systemd unit for auto-start
    _os_podman_generate_systemd "$module_name"
    
    os_success "Deployed ${module_name}"
}

os_podman_remove() {
    local deployment_name="$1"
    local remove_volumes="${2:-false}"
    
    os_podman_check || return 1
    
    local stack_dir="${OS_PODMAN_STACKS_DIR}/${deployment_name}"
    
    # Remove systemd unit first
    _os_podman_remove_systemd "$deployment_name"
    
    if [[ -d "$stack_dir" ]]; then
        local compose_cmd
        if compose_cmd=$(os_podman_compose_cmd); then
            cd "$stack_dir" || return 1
            if [[ "$remove_volumes" == "true" ]]; then
                $compose_cmd down -v
            else
                $compose_cmd down
            fi
        fi
        
        if os_confirm "Remove stack directory?" "n"; then
            rm -rf "$stack_dir"
        fi
    else
        podman rm -f "$deployment_name"
    fi
    
    os_success "Removed ${deployment_name}"
}

os_podman_start() {
    local deployment_name="$1"
    
    os_podman_check || return 1
    
    local stack_dir="${OS_PODMAN_STACKS_DIR}/${deployment_name}"
    
    if [[ -d "$stack_dir" ]]; then
        local compose_cmd
        if compose_cmd=$(os_podman_compose_cmd); then
            cd "$stack_dir" && $compose_cmd start
        fi
    else
        podman start "$deployment_name"
    fi
}

os_podman_stop() {
    local deployment_name="$1"
    
    os_podman_check || return 1
    
    local stack_dir="${OS_PODMAN_STACKS_DIR}/${deployment_name}"
    
    if [[ -d "$stack_dir" ]]; then
        local compose_cmd
        if compose_cmd=$(os_podman_compose_cmd); then
            cd "$stack_dir" && $compose_cmd stop
        fi
    else
        podman stop "$deployment_name"
    fi
}

os_podman_restart() {
    local deployment_name="$1"
    os_podman_stop "$deployment_name"
    sleep 1
    os_podman_start "$deployment_name"
}

#-------------------------------------------------------------------------------
# Status & Info
#-------------------------------------------------------------------------------
os_podman_list() {
    os_podman_check || return 1
    
    os_menu_header "Podman Deployments"
    
    echo -e "  ${C_BOLD}Stacks:${C_RESET}"
    if [[ -d "${OS_PODMAN_STACKS_DIR}" ]]; then
        for stack in "${OS_PODMAN_STACKS_DIR}"/*/; do
            if [[ -d "$stack" ]]; then
                local name
                name=$(basename "$stack")
                echo -e "    ${EMOJI_PODMAN} ${name}"
            fi
        done
    fi
    
    echo ""
    echo -e "  ${C_BOLD}All Containers:${C_RESET}"
    podman ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

os_podman_status() {
    local deployment_name="$1"
    
    os_podman_check || return 1
    
    local stack_dir="${OS_PODMAN_STACKS_DIR}/${deployment_name}"
    
    if [[ -d "$stack_dir" ]]; then
        local compose_cmd
        if compose_cmd=$(os_podman_compose_cmd); then
            cd "$stack_dir" && $compose_cmd ps
        fi
    else
        podman ps -a --filter "name=${deployment_name}"
    fi
}

os_podman_logs() {
    local deployment_name="$1"
    local lines="${2:-100}"
    
    os_podman_check || return 1
    
    local stack_dir="${OS_PODMAN_STACKS_DIR}/${deployment_name}"
    
    if [[ -d "$stack_dir" ]]; then
        local compose_cmd
        if compose_cmd=$(os_podman_compose_cmd); then
            cd "$stack_dir" && $compose_cmd logs --tail="$lines"
        fi
    else
        podman logs --tail="$lines" "$deployment_name"
    fi
}

os_podman_exec() {
    local deployment_name="$1"
    shift
    local cmd=("$@")
    
    os_podman_check || return 1
    
    if [[ ${#cmd[@]} -eq 0 ]]; then
        cmd=("/bin/sh")
    fi
    
    podman exec -it "$deployment_name" "${cmd[@]}"
}

#-------------------------------------------------------------------------------
# Systemd Integration (for rootless auto-start)
#-------------------------------------------------------------------------------
_os_podman_generate_systemd() {
    local name="$1"
    
    local systemd_dir="${HOME}/.config/systemd/user"
    mkdir -p "$systemd_dir"
    
    # For compose stacks
    local stack_dir="${OS_PODMAN_STACKS_DIR}/${name}"
    
    if [[ -d "$stack_dir" ]]; then
        cat > "${systemd_dir}/podman-${name}.service" << EOF
[Unit]
Description=Podman Stack: ${name}
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${stack_dir}
ExecStart=/usr/bin/podman-compose up -d
ExecStop=/usr/bin/podman-compose down

[Install]
WantedBy=default.target
EOF
    else
        # For single containers
        podman generate systemd --name "$name" --files --new
        mv "container-${name}.service" "${systemd_dir}/"
    fi
    
    systemctl --user daemon-reload
    systemctl --user enable "podman-${name}.service" 2>/dev/null || true
    
    # Enable lingering for rootless containers to start at boot
    if command -v loginctl &> /dev/null; then
        loginctl enable-linger "$USER" 2>/dev/null || true
    fi
}

_os_podman_remove_systemd() {
    local name="$1"
    local systemd_dir="${HOME}/.config/systemd/user"
    
    systemctl --user disable "podman-${name}.service" 2>/dev/null || true
    rm -f "${systemd_dir}/podman-${name}.service"
    rm -f "${systemd_dir}/container-${name}.service"
    systemctl --user daemon-reload
}

#-------------------------------------------------------------------------------
# Backup & Restore
#-------------------------------------------------------------------------------
os_podman_backup() {
    local deployment_name="$1"
    local backup_path="${2:-${OS_DATA_DIR}/backups}"
    
    os_podman_check || return 1
    
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_file="${backup_path}/${deployment_name}_podman_${timestamp}.tar.gz"
    
    mkdir -p "$backup_path"
    
    os_info "Backing up ${deployment_name}..."
    
    local stack_dir="${OS_PODMAN_STACKS_DIR}/${deployment_name}"
    
    if [[ -d "$stack_dir" ]]; then
        local compose_cmd
        if compose_cmd=$(os_podman_compose_cmd); then
            cd "$stack_dir" && $compose_cmd stop
        fi
        
        tar -czf "$backup_file" -C "${OS_PODMAN_STACKS_DIR}" "${deployment_name}"
        
        if compose_cmd=$(os_podman_compose_cmd); then
            $compose_cmd start
        fi
    else
        podman export "$deployment_name" | gzip > "$backup_file"
    fi
    
    os_success "Backup created: ${backup_file}"
    echo "$backup_file"
}

os_podman_restore() {
    local backup_path="$1"
    local deployment_name="${2:-}"
    
    os_podman_check || return 1
    
    if [[ ! -f "$backup_path" ]]; then
        os_error "Backup file not found: ${backup_path}"
        return 1
    fi
    
    os_info "Restoring from ${backup_path}..."
    
    local temp_dir
    temp_dir=$(mktemp -d)
    
    tar -xzf "$backup_path" -C "$temp_dir"
    
    if [[ -z "$deployment_name" ]]; then
        deployment_name=$(ls "$temp_dir" | head -1)
    fi
    
    mv "${temp_dir}/${deployment_name}" "${OS_PODMAN_STACKS_DIR}/"
    
    local compose_cmd
    if compose_cmd=$(os_podman_compose_cmd); then
        cd "${OS_PODMAN_STACKS_DIR}/${deployment_name}" && $compose_cmd up -d
    fi
    
    _os_podman_generate_systemd "$deployment_name"
    
    rm -rf "$temp_dir"
    
    os_success "Restored ${deployment_name}"
}

#-------------------------------------------------------------------------------
# Update
#-------------------------------------------------------------------------------
os_podman_update() {
    local deployment_name="$1"
    
    os_podman_check || return 1
    
    local stack_dir="${OS_PODMAN_STACKS_DIR}/${deployment_name}"
    
    if [[ ! -d "$stack_dir" ]]; then
        os_error "Deployment not found: ${deployment_name}"
        return 1
    fi
    
    os_info "Updating ${deployment_name}..."
    
    local compose_cmd
    if compose_cmd=$(os_podman_compose_cmd); then
        cd "$stack_dir" || return 1
        $compose_cmd pull
        $compose_cmd up -d --force-recreate
    fi
    
    os_success "Updated ${deployment_name}"
}

#-------------------------------------------------------------------------------
# Initialization Flag
#-------------------------------------------------------------------------------
OS_PODMAN_ADAPTER_LOADED=true
