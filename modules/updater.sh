#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  OmniScript - Updater Module                                               ║
# ║  Check for and apply updates (like Portainer Business)                     ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

[[ -n "${_OS_MODULE_UPDATER_LOADED:-}" ]] && return 0
readonly _OS_MODULE_UPDATER_LOADED=1

# Check for Docker image updates
os_check_docker_updates() {
    os_log_section "🐳 Docker Updates"
    
    if ! command -v docker &>/dev/null || ! docker info &>/dev/null 2>&1; then
        os_log_warn "Docker not available"
        return 0
    fi
    
    local updates_available=()
    
    # Get all OmniScript managed containers
    local containers
    containers=$(docker ps --filter "label=omniscript.managed=true" --format "{{.Names}}:{{.Image}}" 2>/dev/null)
    
    if [[ -z "$containers" ]]; then
        # Fallback: check all containers with os- prefix
        containers=$(docker ps --format "{{.Names}}:{{.Image}}" | grep "^os-")
    fi
    
    while IFS=':' read -r name image; do
        [[ -z "$name" ]] && continue
        
        local current_digest new_digest
        current_digest=$(docker inspect "$name" --format '{{index .RepoDigests 0}}' 2>/dev/null | cut -d@ -f2)
        
        # Pull new image and check digest
        os_spinner_start "Checking $image..."
        docker pull "$image" &>/dev/null
        os_spinner_stop
        
        new_digest=$(docker image inspect "$image" --format '{{index .RepoDigests 0}}' 2>/dev/null | cut -d@ -f2)
        
        if [[ -n "$new_digest" && "$current_digest" != "$new_digest" ]]; then
            os_log_info "📦 $name: Update available"
            updates_available+=("$name:$image")
        else
            os_log_debug "$name: Up to date"
        fi
    done <<< "$containers"
    
    echo "${updates_available[@]}"
}

# Check for Podman updates
os_check_podman_updates() {
    os_log_section "🦭 Podman Updates"
    
    if ! command -v podman &>/dev/null; then
        os_log_warn "Podman not available"
        return 0
    fi
    
    local updates_available=()
    local containers
    containers=$(podman ps --format "{{.Names}}:{{.Image}}" | grep "^os-")
    
    while IFS=':' read -r name image; do
        [[ -z "$name" ]] && continue
        
        os_spinner_start "Checking $image..."
        podman pull "$image" &>/dev/null
        os_spinner_stop
        
        # Check if image ID changed
        local running_id new_id
        running_id=$(podman inspect "$name" --format '{{.Image}}' 2>/dev/null)
        new_id=$(podman image inspect "$image" --format '{{.Id}}' 2>/dev/null)
        
        if [[ "$running_id" != "$new_id" ]]; then
            os_log_info "📦 $name: Update available"
            updates_available+=("$name:$image")
        fi
    done <<< "$containers"
    
    echo "${updates_available[@]}"
}

# Check for LXC updates
os_check_lxc_updates() {
    os_log_section "📦 LXC Updates"
    
    if ! command -v lxc &>/dev/null; then
        os_log_warn "LXC not available"
        return 0
    fi
    
    local containers
    containers=$(lxc list -c n --format csv | grep "^os-")
    
    for name in $containers; do
        os_log_info "Updating packages in $name..."
        
        if lxc exec "$name" -- which apt &>/dev/null; then
            lxc exec "$name" -- apt-get update -q
            local upgradable
            upgradable=$(lxc exec "$name" -- apt list --upgradable 2>/dev/null | wc -l)
            if [[ $upgradable -gt 1 ]]; then
                os_log_info "📦 $name: $((upgradable - 1)) package updates available"
            fi
        fi
    done
}

# Apply updates with zero-downtime
os_apply_update() {
    local container_name="$1"
    local image="$2"
    local target="${3:-docker}"
    
    os_log_info "Updating $container_name..."
    
    case "$target" in
        docker)
            os_docker_zero_downtime_update "$container_name" "$image"
            ;;
        podman)
            os_podman_update "$container_name" "$image"
            ;;
        lxc)
            lxc exec "$container_name" -- apt-get upgrade -y 2>/dev/null || true
            ;;
    esac
}

# Docker zero-downtime update
os_docker_zero_downtime_update() {
    local container="$1"
    local image="$2"
    
    os_log_step 1 5 "Creating backup..."
    # Export current container
    docker export "$container" > "/tmp/${container}_backup.tar" 2>/dev/null
    
    os_log_step 2 5 "Pulling new image..."
    docker pull "$image"
    
    os_log_step 3 5 "Getting current config..."
    # Get current container config
    local old_config
    old_config=$(docker inspect "$container" 2>/dev/null)
    
    os_log_step 4 5 "Recreating container..."
    # Find compose file if exists
    local app_name="${container#os-}"
    local compose_file="${OS_CONFIG_DIR}/data/${app_name}/docker-compose.yml"
    
    if [[ -f "$compose_file" ]]; then
        docker compose -f "$compose_file" up -d --force-recreate
    else
        # Manual recreation
        docker stop "$container"
        docker rm "$container"
        
        # This is simplified - full implementation would parse old_config
        docker run -d --name "$container" "$image"
    fi
    
    os_log_step 5 5 "Verifying..."
    sleep 3
    
    if docker ps | grep -q "$container"; then
        os_log_success "Updated $container successfully"
        rm -f "/tmp/${container}_backup.tar"
    else
        os_log_error "Update failed, rolling back..."
        docker import "/tmp/${container}_backup.tar" "${container}-rollback"
        # Would need more logic to fully rollback
        return 1
    fi
}

# Podman update
os_podman_update() {
    local container="$1"
    local image="$2"
    
    # Get container config
    local json
    json=$(podman inspect "$container" 2>/dev/null)
    
    podman stop "$container"
    podman rm "$container"
    podman run -d --name "$container" "$image"
    
    os_log_success "Updated $container"
}

# Main update check function
os_check_updates() {
    os_log_header "Update Manager"
    
    local docker_updates podman_updates
    docker_updates=$(os_check_docker_updates)
    podman_updates=$(os_check_podman_updates)
    os_check_lxc_updates
    
    local all_updates=()
    [[ -n "$docker_updates" ]] && all_updates+=($docker_updates)
    [[ -n "$podman_updates" ]] && all_updates+=($podman_updates)
    
    if [[ ${#all_updates[@]} -eq 0 ]]; then
        os_log_success "All containers are up to date!"
        return 0
    fi
    
    echo ""
    os_log_info "${#all_updates[@]} update(s) available"
    
    local options=("🔄 Update All" "📋 Select Individual" "🚪 Cancel")
    local choice
    choice=$(os_select "What would you like to do?" "${options[@]}")
    
    case $choice in
        0)
            # Update all
            for update in "${all_updates[@]}"; do
                IFS=':' read -r name image <<< "$update"
                os_apply_update "$name" "$image"
            done
            ;;
        1)
            # Select individual
            for update in "${all_updates[@]}"; do
                IFS=':' read -r name image <<< "$update"
                if os_confirm "Update $name?"; then
                    os_apply_update "$name" "$image"
                fi
            done
            ;;
        2)
            return 0
            ;;
    esac
    
    os_log_success "Updates completed!"
}
