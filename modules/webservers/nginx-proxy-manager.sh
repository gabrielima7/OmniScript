#!/usr/bin/env bash
#===============================================================================
# OmniScript Module: Nginx Proxy Manager
# Description: Docker-based Reverse Proxy with GUI and Auto-SSL
# Maintainer: OmniScript Team
#===============================================================================

# Metadata
OS_MODULE_NAME="Nginx Proxy Manager"
OS_MODULE_VERSION="2.11.3"
OS_MODULE_DESCRIPTION="Docker-based Reverse Proxy with GUI and Auto-SSL"
OS_MODULE_CATEGORY="Web Servers"
OS_MODULE_SERVICE="nginx-proxy-manager"
OS_MODULE_DATA_DIRS=("npm-data" "npm-letsencrypt")

#-------------------------------------------------------------------------------
# Core Functions
#-------------------------------------------------------------------------------
os_module_install() {
    # NPM is strictly Docker-based in most easy deployments
    if [[ "${OS_CURRENT_TARGET}" != "docker" ]] && [[ "${OS_CURRENT_TARGET}" != "podman" ]]; then
        os_log "WARN" "Nginx Proxy Manager is best supported on Docker/Podman."
        if ! os_confirm "Are you sure you want to proceed on ${OS_CURRENT_TARGET}?" "n"; then
            return 1
        fi
    fi
    
    return 0
}

#-------------------------------------------------------------------------------
# Docker/Podman Deployment
#-------------------------------------------------------------------------------
os_module_compose() {
    local service_name="$1"
    
    # Generate config
    cat << EOF
version: '3.8'
services:
  app:
    image: 'jc21/nginx-proxy-manager:latest'
    container_name: ${service_name}
    restart: unless-stopped
    ports:
      - '80:80'
      - '81:81'
      - '443:443'
    volumes:
      - npm-data:/data
      - npm-letsencrypt:/etc/letsencrypt
    healthcheck:
      test: ["CMD", "/bin/check-health"]
      interval: 10s
      timeout: 3s

volumes:
  npm-data:
  npm-letsencrypt:
EOF
}

os_module_post_install() {
    echo ""
    os_success "Nginx Proxy Manager installed!"
    echo -e "  Admin UI: ${C_BOLD}http://${OS_DOMAIN:-localhost}:81${C_RESET}"
    echo -e "  Default User: ${C_CYAN}admin@example.com${C_RESET}"
    echo -e "  Default Pass: ${C_CYAN}changeme${C_RESET}"
    echo ""
    os_info "Please login and change credentials immediately."
}
