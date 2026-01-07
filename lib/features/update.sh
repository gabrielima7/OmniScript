#!/usr/bin/env bash
#===============================================================================
# OmniScript - Update Library
# Zero-downtime updates and self-update functionality
#===============================================================================
# shellcheck disable=SC2034

#-------------------------------------------------------------------------------
# Update Configuration
#-------------------------------------------------------------------------------
OS_UPDATE_CHECK_URL="https://api.github.com/repos/${OS_REPO}/releases/latest"
OS_UPDATE_SCRIPT_URL="https://raw.githubusercontent.com/${OS_REPO}/${OS_BRANCH}/install.sh"

#-------------------------------------------------------------------------------
# Self-Update
#-------------------------------------------------------------------------------
os_self_update() {
    os_info "Checking for OmniScript updates..."
    
    local latest_version
    latest_version=$(os_get_latest_version)
    
    if [[ -z "$latest_version" ]]; then
        os_error "Could not check for updates"
        return 1
    fi
    
    if [[ "$latest_version" == "$OS_VERSION" ]]; then
        os_success "OmniScript is up to date (v${OS_VERSION})"
        return 0
    fi
    
    if os_version_compare "$OS_VERSION" "ge" "$latest_version"; then
        os_success "OmniScript is up to date (v${OS_VERSION})"
        return 0
    fi
    
    os_info "Update available: v${OS_VERSION} → v${latest_version}"
    
    if ! os_confirm "Update OmniScript?" "y"; then
        return 0
    fi
    
    os_task_start "Downloading update"
    
    local temp_dir
    temp_dir=$(mktemp -d)
    
    if curl -fsSL "https://github.com/${OS_REPO}/archive/refs/tags/v${latest_version}.tar.gz" | tar -xz -C "$temp_dir"; then
        os_task_done "Downloaded v${latest_version}"
    else
        os_task_fail "Download failed"
        rm -rf "$temp_dir"
        return 1
    fi
    
    os_task_start "Installing update"
    
    # Backup current installation
    if [[ -d "${OS_SCRIPT_DIR}" ]]; then
        cp -r "${OS_SCRIPT_DIR}" "${OS_SCRIPT_DIR}.backup"
    fi
    
    # Copy new files
    local new_dir="${temp_dir}/OmniScript-${latest_version#v}"
    
    if [[ -d "$new_dir" ]]; then
        # Preserve user config
        local config_backup="${OS_DATA_DIR}/config.backup"
        [[ -f "${OS_CONFIG_FILE}" ]] && cp "${OS_CONFIG_FILE}" "$config_backup"
        
        # Update files
        cp -r "${new_dir}"/* "${OS_SCRIPT_DIR}/"
        
        # Restore config
        [[ -f "$config_backup" ]] && mv "$config_backup" "${OS_CONFIG_FILE}"
        
        os_task_done "Installed v${latest_version}"
    else
        os_task_fail "Installation failed"
        # Restore backup
        [[ -d "${OS_SCRIPT_DIR}.backup" ]] && mv "${OS_SCRIPT_DIR}.backup" "${OS_SCRIPT_DIR}"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
    rm -rf "${OS_SCRIPT_DIR}.backup"
    
    os_success "OmniScript updated to v${latest_version}"
    os_info "Please restart OmniScript to use the new version"
}

os_get_latest_version() {
    local response
    response=$(curl -fsSL "$OS_UPDATE_CHECK_URL" 2>/dev/null)
    
    if [[ -z "$response" ]]; then
        return 1
    fi
    
    local version
    if command -v jq &> /dev/null; then
        version=$(echo "$response" | jq -r '.tag_name // empty')
    else
        version=$(echo "$response" | grep -oP '"tag_name"\s*:\s*"\K[^"]+')
    fi
    
    # Remove 'v' prefix if present
    echo "${version#v}"
}

os_check_for_updates() {
    local latest
    latest=$(os_get_latest_version)
    
    if [[ -z "$latest" ]]; then
        return 1
    fi
    
    if os_version_compare "$latest" "gt" "$OS_VERSION"; then
        echo "$latest"
        return 0
    fi
    
    return 1
}

#-------------------------------------------------------------------------------
# Deployment Updates
#-------------------------------------------------------------------------------
os_update_deployment() {
    local deployment_name="$1"
    
    os_target_update "$deployment_name"
}

os_update_all() {
    os_info "Updating all deployments..."
    
    local deployments=()
    
    case "${OS_CURRENT_TARGET}" in
        docker)
            if [[ -d "${OS_DOCKER_STACKS_DIR:-}" ]]; then
                for stack in "${OS_DOCKER_STACKS_DIR}"/*/; do
                    [[ -d "$stack" ]] && deployments+=("$(basename "$stack")")
                done
            fi
            ;;
        podman)
            if [[ -d "${OS_PODMAN_STACKS_DIR:-}" ]]; then
                for stack in "${OS_PODMAN_STACKS_DIR}"/*/; do
                    [[ -d "$stack" ]] && deployments+=("$(basename "$stack")")
                done
            fi
            ;;
        lxc)
            while IFS= read -r container; do
                [[ -n "$container" ]] && deployments+=("$container")
            done < <(lxc list --format csv -c n 2>/dev/null)
            ;;
        baremetal)
            if [[ -d "${OS_BAREMETAL_DEPLOY_DIR:-}" ]]; then
                for reg in "${OS_BAREMETAL_DEPLOY_DIR}"/*.json; do
                    [[ -f "$reg" ]] && deployments+=("$(basename "$reg" .json)")
                done
            fi
            ;;
    esac
    
    if [[ ${#deployments[@]} -eq 0 ]]; then
        os_info "No deployments to update"
        return
    fi
    
    for deployment in "${deployments[@]}"; do
        os_info "Updating: ${deployment}"
        os_target_update "$deployment"
    done
    
    os_success "All deployments updated"
}

#-------------------------------------------------------------------------------
# Zero-Downtime Update Logic
#-------------------------------------------------------------------------------
os_zero_downtime_update() {
    local deployment_name="$1"
    local new_image="${2:-}"
    
    os_info "Starting zero-downtime update for ${deployment_name}..."
    
    case "${OS_CURRENT_TARGET}" in
        docker)
            _os_docker_zero_downtime_update "$deployment_name" "$new_image"
            ;;
        podman)
            _os_podman_zero_downtime_update "$deployment_name" "$new_image"
            ;;
        *)
            # For other targets, do simple update
            os_target_update "$deployment_name"
            ;;
    esac
}

_os_docker_zero_downtime_update() {
    local deployment_name="$1"
    local new_image="$2"
    
    local stack_dir="${OS_DOCKER_STACKS_DIR}/${deployment_name}"
    
    if [[ ! -d "$stack_dir" ]]; then
        os_error "Deployment not found: ${deployment_name}"
        return 1
    fi
    
    local compose_cmd
    compose_cmd=$(os_docker_compose_cmd)
    
    cd "$stack_dir" || return 1
    
    # Pull new images
    os_task_start "Pulling new images"
    $compose_cmd pull 2>/dev/null
    os_task_done "Images pulled"
    
    # Rolling update each service
    local services
    services=$($compose_cmd config --services 2>/dev/null)
    
    for service in $services; do
        os_task_start "Rolling update: ${service}"
        
        # Create new container
        $compose_cmd up -d --no-deps "$service" 2>/dev/null
        
        # Wait for health check
        local retries=30
        while [[ $retries -gt 0 ]]; do
            local status
            status=$($compose_cmd ps "$service" --format json 2>/dev/null | jq -r '.[0].Health // "none"')
            
            if [[ "$status" == "healthy" ]] || [[ "$status" == "none" ]]; then
                break
            fi
            
            sleep 2
            ((retries--))
        done
        
        if [[ $retries -eq 0 ]]; then
            os_task_fail "Health check timeout: ${service}"
            os_warn "Rolling back ${service}..."
            $compose_cmd up -d --no-deps "$service" 2>/dev/null
        else
            os_task_done "Updated: ${service}"
        fi
    done
    
    os_success "Zero-downtime update complete"
}

_os_podman_zero_downtime_update() {
    local deployment_name="$1"
    local new_image="$2"
    
    local stack_dir="${OS_PODMAN_STACKS_DIR}/${deployment_name}"
    
    if [[ ! -d "$stack_dir" ]]; then
        os_error "Deployment not found: ${deployment_name}"
        return 1
    fi
    
    local compose_cmd
    compose_cmd=$(os_podman_compose_cmd) || {
        os_error "Podman Compose required for zero-downtime updates"
        return 1
    }
    
    cd "$stack_dir" || return 1
    
    $compose_cmd pull 2>/dev/null
    $compose_cmd up -d --force-recreate 2>/dev/null
    
    os_success "Update complete"
}

#-------------------------------------------------------------------------------
# Update Check on Startup
#-------------------------------------------------------------------------------
os_startup_update_check() {
    if [[ "${OS_AUTO_UPDATE:-false}" == "true" ]]; then
        local latest
        if latest=$(os_check_for_updates); then
            os_print_info "Update available: v${OS_VERSION} → v${latest}"
            os_print_info "Run 'omniscript update' to update"
        fi
    fi
}

#-------------------------------------------------------------------------------
# Interactive Update Menu
#-------------------------------------------------------------------------------
os_update_menu() {
    while true; do
        os_clear_screen
        os_banner_small
        
        os_menu_header "Update Manager"
        
        os_menu_item "1" "${EMOJI_UPDATE}" "Update OmniScript" "Check and install OmniScript updates"
        os_menu_item "2" "${EMOJI_DOCKER}" "Update Deployment" "Update a specific deployment"
        os_menu_item "3" "${EMOJI_ROCKET}" "Update All" "Update all deployments"
        os_menu_item "4" "${EMOJI_SEARCH}" "Check for Updates" "Check available updates"
        
        os_menu_footer
        
        os_select "Choose option" "Update OmniScript" "Update Deployment" "Update All" "Check for Updates" "Back"
        
        case $OS_SELECTED_INDEX in
            0) os_self_update ;;
            1) os_update_interactive ;;
            2) os_update_all ;;
            3) 
                local latest
                if latest=$(os_check_for_updates); then
                    os_print_info "OmniScript update available: v${latest}"
                else
                    os_success "OmniScript is up to date"
                fi
                ;;
            4|255) break ;;
        esac
        
        echo ""
        read -rp "Press Enter to continue..."
    done
}

os_update_interactive() {
    local deployments=()
    
    case "${OS_CURRENT_TARGET}" in
        docker)
            [[ -d "${OS_DOCKER_STACKS_DIR:-}" ]] && \
                for d in "${OS_DOCKER_STACKS_DIR}"/*/; do [[ -d "$d" ]] && deployments+=("$(basename "$d")"); done
            ;;
        podman)
            [[ -d "${OS_PODMAN_STACKS_DIR:-}" ]] && \
                for d in "${OS_PODMAN_STACKS_DIR}"/*/; do [[ -d "$d" ]] && deployments+=("$(basename "$d")"); done
            ;;
    esac
    
    if [[ ${#deployments[@]} -eq 0 ]]; then
        os_warn "No deployments found"
        return
    fi
    
    os_select "Select deployment to update" "${deployments[@]}"
    
    if [[ $? -eq 0 ]]; then
        os_zero_downtime_update "$OS_SELECTED_VALUE"
    fi
}

#-------------------------------------------------------------------------------
# Initialization Flag
#-------------------------------------------------------------------------------
OS_UPDATE_LOADED=true
