#!/usr/bin/env bash
#===============================================================================
# OmniScript Module: Traefik
# Deploy Traefik reverse proxy with automatic HTTPS
#===============================================================================
# shellcheck disable=SC2034

#-------------------------------------------------------------------------------
# Module Metadata
#-------------------------------------------------------------------------------
OS_MODULE_NAME="traefik"
OS_MODULE_VERSION="1.0.0"
OS_MODULE_DESCRIPTION="Traefik - Cloud-native reverse proxy and load balancer"
OS_MODULE_CATEGORY="webservers"
OS_MODULE_SERVICE="traefik"

#-------------------------------------------------------------------------------
# Default Configuration
#-------------------------------------------------------------------------------
TRAEFIK_HTTP_PORT="${TRAEFIK_HTTP_PORT:-80}"
TRAEFIK_HTTPS_PORT="${TRAEFIK_HTTPS_PORT:-443}"
TRAEFIK_DASHBOARD_PORT="${TRAEFIK_DASHBOARD_PORT:-8080}"
TRAEFIK_ACME_EMAIL="${TRAEFIK_ACME_EMAIL:-${OS_EMAIL:-}}"

#-------------------------------------------------------------------------------
# Docker Compose
#-------------------------------------------------------------------------------
os_module_compose() {
    local dashboard_password
    dashboard_password=$(os_get_or_create_password "traefik_dashboard" 16)
    
    local version
    version=$(os_get_best_tag "traefik" "v2.10")
    
    cat << EOF
version: "3.8"

services:
  traefik:
    image: traefik:${version}
    container_name: traefik
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    ports:
      - "${TRAEFIK_HTTP_PORT}:80"
      - "${TRAEFIK_HTTPS_PORT}:443"
      - "${TRAEFIK_DASHBOARD_PORT}:8080"
    command:
      - --api.dashboard=true
      - --api.insecure=true
      - --providers.docker=true
      - --providers.docker.exposedbydefault=false
      - --entrypoints.web.address=:80
      - --entrypoints.websecure.address=:443
      - --entrypoints.web.http.redirections.entrypoint.to=websecure
      - --entrypoints.web.http.redirections.entrypoint.scheme=https
      - --certificatesresolvers.letsencrypt.acme.email=${TRAEFIK_ACME_EMAIL:-admin@localhost}
      - --certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json
      - --certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web
      - --log.level=INFO
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - traefik-letsencrypt:/letsencrypt
    labels:
      - traefik.enable=true
      - traefik.http.routers.dashboard.rule=Host(\`traefik.localhost\`)
      - traefik.http.routers.dashboard.service=api@internal
    networks:
      - traefik-network

networks:
  traefik-network:
    driver: bridge
    name: traefik-network

volumes:
  traefik-letsencrypt:
EOF
    
    os_success "Traefik deployed!"
    os_info "Dashboard: http://localhost:${TRAEFIK_DASHBOARD_PORT}"
    os_info ""
    os_info "To expose a service, add these labels to your container:"
    os_info "  - traefik.enable=true"
    os_info "  - traefik.http.routers.myapp.rule=Host(\`myapp.example.com\`)"
    os_info "  - traefik.http.routers.myapp.tls.certresolver=letsencrypt"
}

#-------------------------------------------------------------------------------
# Bare Metal (Not recommended)
#-------------------------------------------------------------------------------
os_module_baremetal() {
    os_warn "Traefik is best deployed with Docker"
    os_info "For bare metal, consider using Nginx or Caddy instead"
    
    if ! os_confirm "Continue with bare metal installation?" "n"; then
        return 1
    fi
    
    # Download binary
    local arch
    arch=$(os_get_arch)
    
    case "$arch" in
        amd64|x86_64) arch="amd64" ;;
        arm64|aarch64) arch="arm64" ;;
        *) os_error "Unsupported architecture: ${arch}"; return 1 ;;
    esac
    
    local version="v2.10.7"
    local url="https://github.com/traefik/traefik/releases/download/${version}/traefik_${version}_linux_${arch}.tar.gz"
    
    os_info "Downloading Traefik ${version}..."
    
    local temp_dir
    temp_dir=$(mktemp -d)
    
    curl -fsSL "$url" | tar -xz -C "$temp_dir"
    os_run_sudo "mv ${temp_dir}/traefik /usr/local/bin/"
    os_run_sudo "chmod +x /usr/local/bin/traefik"
    
    rm -rf "$temp_dir"
    
    # Create config directory
    os_run_sudo "mkdir -p /etc/traefik"
    
    # Create basic config
    cat << 'EOF' | sudo tee /etc/traefik/traefik.yml
entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"

api:
  dashboard: true
  insecure: true

providers:
  file:
    directory: /etc/traefik/conf.d
    watch: true

log:
  level: INFO
EOF
    
    os_run_sudo "mkdir -p /etc/traefik/conf.d"
    
    # Create systemd service
    cat << 'EOF' | sudo tee /etc/systemd/system/traefik.service
[Unit]
Description=Traefik
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/traefik --configFile=/etc/traefik/traefik.yml
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    
    os_run_sudo "systemctl daemon-reload"
    os_service_enable traefik
    os_service_start traefik
    
    os_success "Traefik installed and running"
}
