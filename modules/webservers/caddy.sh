#!/usr/bin/env bash
#===============================================================================
# OmniScript Module: Caddy
# Description: Powerful, enterprise-ready, open source web server with automatic HTTPS
# Maintainer: OmniScript Team
#===============================================================================

# Metadata
OS_MODULE_NAME="Caddy"
OS_MODULE_VERSION="2.7.6"
OS_MODULE_DESCRIPTION="Web server with automatic HTTPS"
OS_MODULE_CATEGORY="Web Servers"
OS_MODULE_SERVICE="caddy"
OS_MODULE_DATA_DIRS=("caddy-data" "caddy-config")

#-------------------------------------------------------------------------------
# Docker/Podman Deployment
#-------------------------------------------------------------------------------
os_module_compose() {
    local service_name="$1"
    
    cat << EOF
version: '3.8'
services:
  caddy:
    image: caddy:2.7.6-alpine
    container_name: ${service_name}
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"
    volumes:
      - caddy-data:/data
      - caddy-config:/config
      - ./Caddyfile:/etc/caddy/Caddyfile

volumes:
  caddy-data:
  caddy-config:
EOF

    # Create default Caddyfile if not exists
    if [[ ! -f "Caddyfile" ]]; then
        cat > "Caddyfile" << 'CADDY'
:80 {
    respond "Welcome to OmniScript Caddy! 🚀"
}
CADDY
    fi
}

os_module_post_install() {
    echo ""
    os_success "Caddy installed!"
    echo -e "  Config: ${C_BOLD}./Caddyfile${C_RESET}"
    echo -e "  Docs:   https://caddyserver.com/docs/"
    echo ""
}
