#!/usr/bin/env bash
#===============================================================================
# OmniScript Module: Redis
# Deploy Redis in-memory cache with Docker, Podman, or native packages
#===============================================================================
# shellcheck disable=SC2034

#-------------------------------------------------------------------------------
# Module Metadata
#-------------------------------------------------------------------------------
OS_MODULE_NAME="redis"
OS_MODULE_VERSION="1.0.0"
OS_MODULE_DESCRIPTION="Redis - In-memory data structure store and cache"
OS_MODULE_CATEGORY="databases"
OS_MODULE_SERVICE="redis-server"
OS_MODULE_DATA_DIRS="/var/lib/redis"
OS_MODULE_CONFIG_FILES="/etc/redis"

#-------------------------------------------------------------------------------
# Default Configuration
#-------------------------------------------------------------------------------
REDIS_PORT="${REDIS_PORT:-6379}"

#-------------------------------------------------------------------------------
# Docker Compose
#-------------------------------------------------------------------------------
os_module_compose() {
    local password
    password=$(os_get_or_create_password "redis_password" 24)
    
    local version
    version=$(os_get_best_tag "redis" "alpine")
    
    cat << EOF
version: "3.8"

services:
  redis:
    image: redis:${version}
    container_name: redis
    restart: unless-stopped
    command: redis-server --requirepass ${password}
    ports:
      - "${REDIS_PORT}:6379"
    volumes:
      - redis-data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${password}", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  redis-data:
EOF
    
    os_info "Redis password: ${password}"
}

#-------------------------------------------------------------------------------
# Bare Metal Installation
#-------------------------------------------------------------------------------
os_module_baremetal() {
    case "${OS_DISTRO_FAMILY}" in
        debian)
            os_baremetal_install_packages "redis" "redis-server"
            ;;
        rhel)
            os_baremetal_install_packages "redis" "redis"
            ;;
        arch)
            os_baremetal_install_packages "redis" "redis"
            ;;
        alpine)
            os_baremetal_install_packages "redis" "redis"
            ;;
        *)
            os_error "Bare metal installation not supported for ${OS_DISTRO_ID}"
            return 1
            ;;
    esac
    
    os_service_enable redis-server 2>/dev/null || os_service_enable redis
    os_service_start redis-server 2>/dev/null || os_service_start redis
    
    os_success "Redis installed and running on port ${REDIS_PORT}"
}

#-------------------------------------------------------------------------------
# LXC Installation
#-------------------------------------------------------------------------------
os_module_lxc() {
    local container="$1"
    
    lxc exec "$container" -- apt-get update
    lxc exec "$container" -- apt-get install -y redis-server
    lxc exec "$container" -- systemctl enable redis-server
    lxc exec "$container" -- systemctl start redis-server
    
    os_success "Redis installed in ${container}"
}

#-------------------------------------------------------------------------------
# Uninstall
#-------------------------------------------------------------------------------
os_module_uninstall() {
    os_pkg_remove "redis-server" 2>/dev/null || os_pkg_remove "redis"
}
