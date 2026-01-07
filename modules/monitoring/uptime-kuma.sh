#!/usr/bin/env bash
#===============================================================================
# OmniScript Module: Uptime Kuma
# Description: A fancy self-hosted monitoring tool
# Maintainer: OmniScript Team
#===============================================================================

# Metadata
OS_MODULE_NAME="Uptime Kuma"
OS_MODULE_VERSION="1.23.13"
OS_MODULE_DESCRIPTION="A fancy self-hosted monitoring tool"
OS_MODULE_CATEGORY="Monitoring"
OS_MODULE_SERVICE="uptime-kuma"
OS_MODULE_DATA_DIRS=("uptime-kuma-data")

#-------------------------------------------------------------------------------
# Docker/Podman Deployment
#-------------------------------------------------------------------------------
os_module_compose() {
    local service_name="$1"
    
    cat << EOF
version: '3.8'
services:
  uptime-kuma:
    image: louislam/uptime-kuma:1
    container_name: ${service_name}
    restart: unless-stopped
    ports:
      - '3001:3001'
    volumes:
      - uptime-kuma-data:/app/data
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3001"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  uptime-kuma-data:
EOF
}

os_module_post_install() {
    echo ""
    os_success "Uptime Kuma installed!"
    echo -e "  Access: ${C_BOLD}http://${OS_DOMAIN:-localhost}:3001${C_RESET}"
    echo ""
}

#-------------------------------------------------------------------------------
# Bare Metal Support (Node.js required)
#-------------------------------------------------------------------------------
os_module_baremetal() {
    if ! command -v node &> /dev/null; then
        os_error "Node.js is required for Uptime Kuma."
        os_info "Run 'omniscript install nodejs' first."
        return 1
    fi
    
    if ! command -v npm &> /dev/null; then
        os_error "npm is required."
        return 1
    fi
    
    if ! command -v git &> /dev/null; then
        os_pkg_install git
    fi
    
    os_info "Cloning Uptime Kuma..."
    git clone https://github.com/louislam/uptime-kuma.git /opt/uptime-kuma
    cd /opt/uptime-kuma || return 1
    
    os_info "Installing dependencies..."
    npm run setup
    
    # Install PM2 if not present
    if ! command -v pm2 &> /dev/null; then
        npm install pm2 -g
    fi
    
    pm2 start server/server.js --name uptime-kuma
    pm2 save
    pm2 startup
    
    os_success "Uptime Kuma installed on Bare Metal via PM2"
}
