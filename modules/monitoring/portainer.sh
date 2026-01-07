#!/usr/bin/env bash
#===============================================================================
# OmniScript Module: Portainer
# Deploy Portainer container management UI
#===============================================================================
# shellcheck disable=SC2034

#-------------------------------------------------------------------------------
# Module Metadata
#-------------------------------------------------------------------------------
OS_MODULE_NAME="portainer"
OS_MODULE_VERSION="1.0.0"
OS_MODULE_DESCRIPTION="Portainer - Container management made easy"
OS_MODULE_CATEGORY="monitoring"

#-------------------------------------------------------------------------------
# Default Configuration
#-------------------------------------------------------------------------------
PORTAINER_PORT="${PORTAINER_PORT:-9443}"
PORTAINER_HTTP_PORT="${PORTAINER_HTTP_PORT:-9000}"

#-------------------------------------------------------------------------------
# Docker Compose
#-------------------------------------------------------------------------------
os_module_compose() {
    local version
    version=$(os_get_best_tag "portainer/portainer-ce" "latest")
    
    cat << EOF
version: "3.8"

services:
  portainer:
    image: portainer/portainer-ce:${version}
    container_name: portainer
    restart: unless-stopped
    ports:
      - "${PORTAINER_HTTP_PORT}:9000"
      - "${PORTAINER_PORT}:9443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer-data:/data
    security_opt:
      - no-new-privileges:true

volumes:
  portainer-data:
EOF
    
    os_info "Portainer will be available at:"
    os_info "  HTTPS: https://localhost:${PORTAINER_PORT}"
    os_info "  HTTP:  http://localhost:${PORTAINER_HTTP_PORT}"
}

#-------------------------------------------------------------------------------
# Bare Metal (Not Supported)
#-------------------------------------------------------------------------------
os_module_baremetal() {
    os_error "Portainer requires Docker or Podman"
    os_info "Please switch target to Docker or Podman and try again"
    return 1
}
