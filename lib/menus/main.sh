#!/usr/bin/env bash
#===============================================================================
# OmniScript - Main Menu Library
# Primary navigation and module installation interface
#===============================================================================
# shellcheck disable=SC2034

#-------------------------------------------------------------------------------
# Main Menu
#-------------------------------------------------------------------------------
os_main_menu() {
    while true; do
        os_clear_screen
        os_banner
        os_show_target_info
        
        os_menu_header "Main Menu"
        
        os_menu_item "1" "${EMOJI_ROCKET}" "Quick Install" "Deploy popular applications"
        os_menu_item "2" "${EMOJI_PACKAGE}" "Applications" "Browse application categories"
        os_menu_item "3" "${EMOJI_BUILDER}" "Builder Stack" "Compose complete environments"
        os_menu_item "4" "${EMOJI_SEARCH}" "Search" "Search for applications and images"
        os_menu_divider
        os_menu_item "5" "${EMOJI_BACKUP}" "Backup/Restore" "Manage deployment backups"
        os_menu_item "6" "${EMOJI_UPDATE}" "Updates" "Update deployments and OmniScript"
        os_menu_item "7" "${EMOJI_GEAR}" "Settings" "Configure OmniScript"
        os_menu_divider
        os_menu_item "0" "🚪" "Exit" ""
        
        echo ""
        os_select "Choose option" \
            "Quick Install" \
            "Applications" \
            "Builder Stack" \
            "Search" \
            "Backup/Restore" \
            "Updates" \
            "Settings" \
            "Exit"
        
        case $OS_SELECTED_INDEX in
            0) os_quick_install_menu ;;
            1) os_applications_menu ;;
            2) os_builder_menu ;;
            3) os_search_interactive ;;
            4) os_backup_menu ;;
            5) os_update_menu ;;
            6) os_settings_menu ;;
            7|255) 
                os_clear_screen
                os_success "Thanks for using OmniScript! ${EMOJI_ROCKET}"
                exit 0
                ;;
        esac
    done
}

#-------------------------------------------------------------------------------
# Quick Install Menu
#-------------------------------------------------------------------------------
os_quick_install_menu() {
    while true; do
        os_clear_screen
        os_banner_small
        
        os_menu_header "Quick Install - Popular Applications"
        
        echo -e "  ${C_DIM}Target: ${OS_TARGET_ICONS[$OS_CURRENT_TARGET]} ${OS_TARGET_NAMES[$OS_CURRENT_TARGET]}${C_RESET}"
        echo ""
        
        # Define popular apps based on target
        # Option 0 is standardized as Back
        local apps=(
            "Portainer - Container management UI"
            "Nginx Proxy Manager - Reverse proxy with SSL"
            "PostgreSQL - Relational database"
            "Redis - In-memory cache"
            "Traefik - Cloud-native proxy"
            "Uptime Kuma - Uptime monitoring"
            "Netdata - Real-time monitoring"
            "Nextcloud - Self-hosted cloud"
        )
        
        os_select "Select application" "${apps[@]}"
        
        case $OS_SELECTED_INDEX in
            0) os_install_module "portainer" ;;
            1) os_install_module "nginx-proxy-manager" ;;
            2) os_install_module "postgresql" ;;
            3) os_install_module "redis" ;;
            4) os_install_module "traefik" ;;
            5) os_install_module "uptime-kuma" ;;
            6) os_install_module "netdata" ;;
            7) os_install_module "nextcloud" ;;
            255) return ;;
        esac
        
        echo ""
        read -rp "Press Enter to continue..."
    done
}

#-------------------------------------------------------------------------------
# Applications Menu
#-------------------------------------------------------------------------------
os_applications_menu() {
    while true; do
        os_clear_screen
        os_banner_small
        
        os_menu_header "Application Categories"
        
        local categories=(
            "${EMOJI_DATABASE} Databases"
            "${EMOJI_WEB} Web Servers"
            "${EMOJI_CODE} Development Tools"
            "📊 Monitoring"
            "🔒 Security"
            "☁️ Cloud & Storage"
            "📧 Communication"
            "🎮 Media & Gaming"
        )
        
        os_select "Select category" "${categories[@]}"
        
        case $OS_SELECTED_INDEX in
            0) os_category_databases ;;
            1) os_category_webservers ;;
            2) os_category_devtools ;;
            3) os_category_monitoring ;;
            4) os_category_security ;;
            5) os_category_cloud ;;
            6) os_category_communication ;;
            7) os_category_media ;;
            255) return ;;
        esac
    done
}

os_category_databases() {
    local apps=(
        "PostgreSQL - Advanced relational database"
        "MySQL - Popular relational database"
        "MariaDB - MySQL fork"
        "MongoDB - Document database"
        "Redis - In-memory cache/store"
        "ClickHouse - Analytics database"
        "InfluxDB - Time-series database"
        "Back"
    )
    
    _os_category_menu "Databases" "${apps[@]}"
}

os_category_webservers() {
    local apps=(
        "Nginx - High-performance web server"
        "Caddy - Automatic HTTPS web server"
        "Traefik - Cloud-native reverse proxy"
        "Nginx Proxy Manager - GUI reverse proxy"
        "HAProxy - Load balancer"
        "Apache - Traditional web server"
        "Back"
    )
    
    _os_category_menu "Web Servers" "${apps[@]}"
}

os_category_devtools() {
    local apps=(
        "GitLab - DevOps platform"
        "Gitea - Lightweight Git service"
        "Jenkins - CI/CD automation"
        "Drone - Container-native CI"
        "SonarQube - Code quality"
        "Vault - Secrets management"
        "Node.js - JavaScript runtime"
        "Back"
    )
    
    _os_category_menu "Development Tools" "${apps[@]}"
}

os_category_monitoring() {
    local apps=(
        "Grafana - Visualization platform"
        "Prometheus - Metrics & alerting"
        "Netdata - Real-time monitoring"
        "Uptime Kuma - Uptime monitoring"
        "Zabbix - Enterprise monitoring"
        "Loki - Log aggregation"
        "Back"
    )
    
    _os_category_menu "Monitoring" "${apps[@]}"
}

os_category_security() {
    local apps=(
        "Keycloak - Identity management"
        "Authelia - Authentication server"
        "Vaultwarden - Password manager"
        "CrowdSec - Security engine"
        "Fail2Ban - Intrusion prevention"
        "WireGuard - VPN"
        "Back"
    )
    
    _os_category_menu "Security" "${apps[@]}"
}

os_category_cloud() {
    local apps=(
        "Nextcloud - Self-hosted cloud"
        "MinIO - S3-compatible storage"
        "Syncthing - File synchronization"
        "FileBrowser - Web file manager"
        "Seafile - File sync & share"
        "Back"
    )
    
    _os_category_menu "Cloud & Storage" "${apps[@]}"
}

os_category_communication() {
    local apps=(
        "Rocket.Chat - Team collaboration"
        "Mattermost - Team messaging"
        "Matrix/Synapse - Decentralized chat"
        "Mailcow - Email server"
        "Back"
    )
    
    _os_category_menu "Communication" "${apps[@]}"
}

os_category_media() {
    local apps=(
        "Jellyfin - Media server"
        "Plex - Media server"
        "Photoprism - AI photo app"
        "Immich - Photo management"
        "Audiobookshelf - Audiobook server"
        "Back"
    )
    
    _os_category_menu "Media & Gaming" "${apps[@]}"
}

_os_category_menu() {
    local category="$1"
    shift
    local apps=("$@")
    
    while true; do
        os_clear_screen
        os_banner_small
        
        os_menu_header "${category}"
        
        os_select "Select application" "${apps[@]}"
        
        local last_index=$((${#apps[@]} - 1))
        
        if [[ $OS_SELECTED_INDEX -eq $last_index ]] || [[ $OS_SELECTED_INDEX -eq 255 ]]; then
            return
        fi
        
        # Extract module name from selection
        local selection="${apps[$OS_SELECTED_INDEX]}"
        local module_name
        module_name=$(echo "$selection" | cut -d' ' -f1 | tr '[:upper:]' '[:lower:]' | tr -d '.')
        
        os_install_module "$module_name"
        
        echo ""
        read -rp "Press Enter to continue..."
    done
}

#-------------------------------------------------------------------------------
# Backup Menu
#-------------------------------------------------------------------------------
os_backup_menu() {
    while true; do
        os_clear_screen
        os_banner_small
        
        os_menu_header "Backup & Restore"
        
        os_select "Choose option" \
            "Create Backup" \
            "Restore Backup" \
            "List Backups" \
            "Cleanup Old Backups" \
            "Back"
        
        case $OS_SELECTED_INDEX in
            0) os_backup_interactive ;;
            1) os_restore_interactive ;;
            2) os_list_backups ;;
            3) os_cleanup_old_backups ;;
            4|255) return ;;
        esac
        
        echo ""
        read -rp "Press Enter to continue..."
    done
}

#-------------------------------------------------------------------------------
# Module Installation
#-------------------------------------------------------------------------------
os_install_module() {
    local module_name="$1"
    shift
    local args=("$@")
    
    os_info "Installing ${module_name}..."
    
    # Find module file
    local module_file
    module_file=$(find "${OS_MODULES_DIR}" -name "${module_name}.sh" 2>/dev/null | head -1)
    
    if [[ -z "$module_file" ]]; then
        # Try to find by partial match
        module_file=$(find "${OS_MODULES_DIR}" -name "*${module_name}*.sh" 2>/dev/null | head -1)
    fi
    
    if [[ -z "$module_file" ]]; then
        os_warn "Module not found: ${module_name}"
        os_info "Searching online..."
        
        # Try to deploy from image directly
        if [[ "${OS_CURRENT_TARGET}" == "docker" ]] || [[ "${OS_CURRENT_TARGET}" == "podman" ]]; then
            if os_confirm "Deploy ${module_name} from Docker Hub?" "y"; then
                _os_deploy_from_image "$module_name" "${args[@]}"
                return
            fi
        fi
        return 1
    fi
    
    os_target_deploy "$module_name" "${args[@]}"
}

os_remove_module() {
    local module_name="${1:-}"
    
    if [[ -z "$module_name" ]]; then
        os_error "Module name required"
        return 1
    fi
    
    if os_confirm "Remove ${module_name}?" "n"; then
        os_target_remove "$module_name"
    fi
}

_os_deploy_from_image() {
    local image="$1"
    shift
    
    # Get best tag
    local tag
    tag=$(os_get_best_tag "$image")
    
    os_info "Using image: ${image}:${tag}"
    
    # Prompt for basic configuration
    local name
    name=$(os_prompt "Container name" "$image")
    
    local port
    port=$(os_prompt "Host port (leave empty to skip)" "")
    
    # Create simple compose file
    local stack_dir="${OS_DATA_DIR}/${OS_CURRENT_TARGET}/stacks/${name}"
    mkdir -p "$stack_dir"
    
    cat > "${stack_dir}/docker-compose.yml" << EOF
version: "3.8"

services:
  ${name}:
    image: ${image}:${tag}
    container_name: ${name}
    restart: unless-stopped
EOF
    
    if [[ -n "$port" ]]; then
        cat >> "${stack_dir}/docker-compose.yml" << EOF
    ports:
      - "${port}:${port}"
EOF
    fi
    
    os_target_deploy "$name"
}

#-------------------------------------------------------------------------------
# Initialization Flag
#-------------------------------------------------------------------------------
OS_MAIN_MENU_LOADED=true
