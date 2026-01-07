#!/usr/bin/env bash
#===============================================================================
# OmniScript - Docker Target Adapter
# Deploy, manage, and orchestrate Docker containers
#===============================================================================
# shellcheck disable=SC2034

#-------------------------------------------------------------------------------
# Docker Configuration
#-------------------------------------------------------------------------------
OS_DOCKER_COMPOSE_VERSION="${OS_DOCKER_COMPOSE_VERSION:-v2}"
OS_DOCKER_DATA_DIR="${OS_DATA_DIR}/docker"
OS_DOCKER_STACKS_DIR="${OS_DOCKER_DATA_DIR}/stacks"

#-------------------------------------------------------------------------------
# Docker Availability Check
#-------------------------------------------------------------------------------
os_docker_check() {
    if ! command -v docker &> /dev/null; then
        os_error "Docker is not installed"
        return 1
    fi
    
    if ! docker info &> /dev/null; then
        os_error "Docker daemon is not running or user lacks permissions"
        os_info "Try: sudo usermod -aG docker \$USER && newgrp docker"
        return 1
    fi
    
    return 0
}

os_docker_compose_cmd() {
    if docker compose version &> /dev/null; then
        echo "docker compose"
    elif command -v docker-compose &> /dev/null; then
        echo "docker-compose"
    else
        os_error "Docker Compose not available"
        return 1
    fi
}

#-------------------------------------------------------------------------------
# Container Lifecycle
#-------------------------------------------------------------------------------
os_docker_deploy() {
    local module_name="$1"
    shift
    local args=("$@")
    
    os_docker_check || return 1
    
    local stack_dir="${OS_DOCKER_STACKS_DIR}/${module_name}"
    local compose_file="${stack_dir}/docker-compose.yml"
    
    mkdir -p "$stack_dir"
    
    # Check if module provides compose file
    local module_compose="${OS_MODULES_DIR}/*/${module_name}.sh"
    # shellcheck disable=SC2086
    if compgen -G "$module_compose" > /dev/null; then
        local module_file
        module_file=$(ls $module_compose 2>/dev/null | head -1)
        
        # Source module and generate compose
        # shellcheck source=/dev/null
        source "$module_file"
        
        if declare -f os_module_compose > /dev/null; then
            os_module_compose "${args[@]}" > "$compose_file"
        fi
    fi
    
    if [[ ! -f "$compose_file" ]]; then
        os_error "No docker-compose.yml found for ${module_name}"
        return 1
    fi
    
    os_info "Deploying ${module_name} with Docker..."
    
    local compose_cmd
    compose_cmd=$(os_docker_compose_cmd)
    
    cd "$stack_dir" || return 1
    $compose_cmd pull
    $compose_cmd up -d
    
    os_success "Deployed ${module_name}"
    os_docker_status "$module_name"
}

os_docker_remove() {
    local deployment_name="$1"
    local remove_volumes="${2:-false}"
    
    os_docker_check || return 1
    
    local stack_dir="${OS_DOCKER_STACKS_DIR}/${deployment_name}"
    
    if [[ ! -d "$stack_dir" ]]; then
        os_error "Deployment not found: ${deployment_name}"
        return 1
    fi
    
    local compose_cmd
    compose_cmd=$(os_docker_compose_cmd)
    
    cd "$stack_dir" || return 1
    
    if [[ "$remove_volumes" == "true" ]]; then
        $compose_cmd down -v
    else
        $compose_cmd down
    fi
    
    if os_confirm "Remove stack directory?" "n"; then
        rm -rf "$stack_dir"
    fi
    
    os_success "Removed ${deployment_name}"
}

os_docker_start() {
    local deployment_name="$1"
    
    os_docker_check || return 1
    
    local stack_dir="${OS_DOCKER_STACKS_DIR}/${deployment_name}"
    
    if [[ -d "$stack_dir" ]]; then
        local compose_cmd
        compose_cmd=$(os_docker_compose_cmd)
        cd "$stack_dir" && $compose_cmd start
    else
        docker start "$deployment_name"
    fi
}

os_docker_stop() {
    local deployment_name="$1"
    
    os_docker_check || return 1
    
    local stack_dir="${OS_DOCKER_STACKS_DIR}/${deployment_name}"
    
    if [[ -d "$stack_dir" ]]; then
        local compose_cmd
        compose_cmd=$(os_docker_compose_cmd)
        cd "$stack_dir" && $compose_cmd stop
    else
        docker stop "$deployment_name"
    fi
}

os_docker_restart() {
    local deployment_name="$1"
    
    os_docker_check || return 1
    
    local stack_dir="${OS_DOCKER_STACKS_DIR}/${deployment_name}"
    
    if [[ -d "$stack_dir" ]]; then
        local compose_cmd
        compose_cmd=$(os_docker_compose_cmd)
        cd "$stack_dir" && $compose_cmd restart
    else
        docker restart "$deployment_name"
    fi
}

#-------------------------------------------------------------------------------
# Container Info
#-------------------------------------------------------------------------------
os_docker_list() {
    os_docker_check || return 1
    
    os_menu_header "Docker Deployments"
    
    echo -e "  ${C_BOLD}Stacks:${C_RESET}"
    if [[ -d "${OS_DOCKER_STACKS_DIR}" ]]; then
        for stack in "${OS_DOCKER_STACKS_DIR}"/*/; do
            if [[ -d "$stack" ]]; then
                local name
                name=$(basename "$stack")
                local status
                status=$(_os_docker_stack_status "$name")
                echo -e "    ${EMOJI_DOCKER} ${name} - ${status}"
            fi
        done
    fi
    
    echo ""
    echo -e "  ${C_BOLD}All Containers:${C_RESET}"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | while read -r line; do
        echo "    $line"
    done
}

_os_docker_stack_status() {
    local stack_name="$1"
    local stack_dir="${OS_DOCKER_STACKS_DIR}/${stack_name}"
    
    if [[ ! -d "$stack_dir" ]]; then
        echo -e "${C_DIM}not found${C_RESET}"
        return
    fi
    
    local compose_cmd
    compose_cmd=$(os_docker_compose_cmd)
    
    cd "$stack_dir" || return
    
    local running
    running=$($compose_cmd ps --filter "status=running" -q 2>/dev/null | wc -l)
    local total
    total=$($compose_cmd ps -q 2>/dev/null | wc -l)
    
    if [[ $running -eq 0 ]]; then
        echo -e "${C_RED}stopped${C_RESET}"
    elif [[ $running -lt $total ]]; then
        echo -e "${C_YELLOW}partial (${running}/${total})${C_RESET}"
    else
        echo -e "${C_GREEN}running (${running})${C_RESET}"
    fi
}

os_docker_status() {
    local deployment_name="$1"
    
    os_docker_check || return 1
    
    local stack_dir="${OS_DOCKER_STACKS_DIR}/${deployment_name}"
    
    if [[ -d "$stack_dir" ]]; then
        local compose_cmd
        compose_cmd=$(os_docker_compose_cmd)
        cd "$stack_dir" && $compose_cmd ps
    else
        docker ps --filter "name=${deployment_name}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    fi
}

os_docker_logs() {
    local deployment_name="$1"
    local lines="${2:-100}"
    
    os_docker_check || return 1
    
    local stack_dir="${OS_DOCKER_STACKS_DIR}/${deployment_name}"
    
    if [[ -d "$stack_dir" ]]; then
        local compose_cmd
        compose_cmd=$(os_docker_compose_cmd)
        cd "$stack_dir" && $compose_cmd logs --tail="$lines"
    else
        docker logs --tail="$lines" "$deployment_name"
    fi
}

os_docker_exec() {
    local deployment_name="$1"
    shift
    local cmd=("$@")
    
    os_docker_check || return 1
    
    if [[ ${#cmd[@]} -eq 0 ]]; then
        cmd=("/bin/sh")
    fi
    
    docker exec -it "$deployment_name" "${cmd[@]}"
}

#-------------------------------------------------------------------------------
# Image Management
#-------------------------------------------------------------------------------
os_docker_pull() {
    local image="$1"
    local tag="${2:-}"
    
    os_docker_check || return 1
    
    if [[ -n "$tag" ]]; then
        image="${image}:${tag}"
    fi
    
    os_info "Pulling image: ${image}"
    docker pull "$image"
}

os_docker_images() {
    os_docker_check || return 1
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
}

os_docker_image_prune() {
    os_docker_check || return 1
    
    if os_confirm "Remove dangling images?" "n"; then
        docker image prune -f
    fi
    
    if os_confirm "Remove all unused images?" "n"; then
        docker image prune -a -f
    fi
}

#-------------------------------------------------------------------------------
# Backup & Restore
#-------------------------------------------------------------------------------
os_docker_backup() {
    local deployment_name="$1"
    local backup_path="${2:-${OS_DATA_DIR}/backups}"
    
    os_docker_check || return 1
    
    local stack_dir="${OS_DOCKER_STACKS_DIR}/${deployment_name}"
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_file="${backup_path}/${deployment_name}_${timestamp}.tar.gz"
    
    mkdir -p "$backup_path"
    
    os_info "Backing up ${deployment_name}..."
    
    # Stop containers for consistent backup
    if [[ -d "$stack_dir" ]]; then
        local compose_cmd
        compose_cmd=$(os_docker_compose_cmd)
        cd "$stack_dir" && $compose_cmd stop
        
        # Backup volumes
        local volumes
        volumes=$($compose_cmd config --volumes 2>/dev/null)
        
        # Create backup archive
        tar -czf "$backup_file" \
            -C "${OS_DOCKER_STACKS_DIR}" "${deployment_name}" \
            2>/dev/null
        
        # Backup Docker volumes
        for vol in $volumes; do
            local vol_name="${deployment_name}_${vol}"
            if docker volume inspect "$vol_name" &> /dev/null; then
                docker run --rm \
                    -v "${vol_name}:/data" \
                    -v "${backup_path}:/backup" \
                    alpine tar czf "/backup/${vol_name}_${timestamp}.tar.gz" -C /data .
            fi
        done
        
        # Restart containers
        $compose_cmd start
    else
        # Single container backup
        docker export "$deployment_name" | gzip > "$backup_file"
    fi
    
    os_success "Backup created: ${backup_file}"
    echo "$backup_file"
}

os_docker_restore() {
    local backup_path="$1"
    local deployment_name="${2:-}"
    
    os_docker_check || return 1
    
    if [[ ! -f "$backup_path" ]]; then
        os_error "Backup file not found: ${backup_path}"
        return 1
    fi
    
    os_info "Restoring from ${backup_path}..."
    
    local temp_dir
    temp_dir=$(mktemp -d)
    
    tar -xzf "$backup_path" -C "$temp_dir"
    
    # Detect deployment name from backup
    if [[ -z "$deployment_name" ]]; then
        deployment_name=$(ls "$temp_dir" | head -1)
    fi
    
    # Move to stacks dir
    mv "${temp_dir}/${deployment_name}" "${OS_DOCKER_STACKS_DIR}/"
    
    # Start the stack
    local compose_cmd
    compose_cmd=$(os_docker_compose_cmd)
    cd "${OS_DOCKER_STACKS_DIR}/${deployment_name}" && $compose_cmd up -d
    
    rm -rf "$temp_dir"
    
    os_success "Restored ${deployment_name}"
}

#-------------------------------------------------------------------------------
# Zero-Downtime Update
#-------------------------------------------------------------------------------
os_docker_update() {
    local deployment_name="$1"
    
    os_docker_check || return 1
    
    local stack_dir="${OS_DOCKER_STACKS_DIR}/${deployment_name}"
    
    if [[ ! -d "$stack_dir" ]]; then
        os_error "Deployment not found: ${deployment_name}"
        return 1
    fi
    
    os_info "Updating ${deployment_name} with zero-downtime..."
    
    local compose_cmd
    compose_cmd=$(os_docker_compose_cmd)
    
    cd "$stack_dir" || return 1
    
    # Pull new images
    os_task_start "Pulling new images"
    $compose_cmd pull
    os_task_done "Images updated"
    
    # Get list of services
    local services
    services=$($compose_cmd config --services)
    
    # Update each service one by one for zero-downtime
    for service in $services; do
        os_task_start "Updating ${service}"
        
        # Scale up new instance
        $compose_cmd up -d --no-deps --scale "${service}=2" "$service" 2>/dev/null || \
        $compose_cmd up -d --no-deps "$service"
        
        # Wait for healthy
        sleep 5
        
        # Scale down to 1
        $compose_cmd up -d --no-deps --scale "${service}=1" "$service" 2>/dev/null || true
        
        os_task_done "Updated ${service}"
    done
    
    os_success "Update complete for ${deployment_name}"
}

#-------------------------------------------------------------------------------
# Docker Compose Generation Helpers
#-------------------------------------------------------------------------------
os_docker_compose_header() {
    cat << 'EOF'
version: "3.8"

services:
EOF
}

os_docker_compose_service() {
    local name="$1"
    local image="$2"
    local ports="${3:-}"
    local volumes="${4:-}"
    local environment="${5:-}"
    local depends_on="${6:-}"
    
    echo "  ${name}:"
    echo "    image: ${image}"
    echo "    container_name: ${name}"
    echo "    restart: unless-stopped"
    
    if [[ -n "$ports" ]]; then
        echo "    ports:"
        IFS=',' read -ra PORT_ARRAY <<< "$ports"
        for port in "${PORT_ARRAY[@]}"; do
            echo "      - \"${port}\""
        done
    fi
    
    if [[ -n "$volumes" ]]; then
        echo "    volumes:"
        IFS=',' read -ra VOL_ARRAY <<< "$volumes"
        for vol in "${VOL_ARRAY[@]}"; do
            echo "      - ${vol}"
        done
    fi
    
    if [[ -n "$environment" ]]; then
        echo "    environment:"
        IFS=',' read -ra ENV_ARRAY <<< "$environment"
        for env in "${ENV_ARRAY[@]}"; do
            echo "      - ${env}"
        done
    fi
    
    if [[ -n "$depends_on" ]]; then
        echo "    depends_on:"
        IFS=',' read -ra DEP_ARRAY <<< "$depends_on"
        for dep in "${DEP_ARRAY[@]}"; do
            echo "      - ${dep}"
        done
    fi
    echo ""
}

os_docker_compose_network() {
    local name="${1:-default}"
    
    cat << EOF

networks:
  ${name}:
    driver: bridge
EOF
}

os_docker_compose_volume() {
    local name="$1"
    
    cat << EOF

volumes:
  ${name}:
EOF
}

#-------------------------------------------------------------------------------
# Initialization Flag
#-------------------------------------------------------------------------------
OS_DOCKER_ADAPTER_LOADED=true
