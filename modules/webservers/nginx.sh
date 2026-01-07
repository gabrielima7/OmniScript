#!/usr/bin/env bash
#===============================================================================
# OmniScript Module: Nginx
# Deploy Nginx web server with Docker, Podman, or native packages
#===============================================================================
# shellcheck disable=SC2034

#-------------------------------------------------------------------------------
# Module Metadata
#-------------------------------------------------------------------------------
OS_MODULE_NAME="nginx"
OS_MODULE_VERSION="1.0.0"
OS_MODULE_DESCRIPTION="Nginx - High-performance web server and reverse proxy"
OS_MODULE_CATEGORY="webservers"
OS_MODULE_SERVICE="nginx"
OS_MODULE_DATA_DIRS="/var/www"
OS_MODULE_CONFIG_FILES="/etc/nginx"

#-------------------------------------------------------------------------------
# Default Configuration
#-------------------------------------------------------------------------------
NGINX_HTTP_PORT="${NGINX_HTTP_PORT:-80}"
NGINX_HTTPS_PORT="${NGINX_HTTPS_PORT:-443}"

#-------------------------------------------------------------------------------
# Docker Compose
#-------------------------------------------------------------------------------
os_module_compose() {
    local version
    version=$(os_get_best_tag "nginx" "alpine")
    
    cat << EOF
version: "3.8"

services:
  nginx:
    image: nginx:${version}
    container_name: nginx
    restart: unless-stopped
    ports:
      - "${NGINX_HTTP_PORT}:80"
      - "${NGINX_HTTPS_PORT}:443"
    volumes:
      - ./conf.d:/etc/nginx/conf.d:ro
      - ./www:/var/www/html:ro
      - ./certs:/etc/nginx/certs:ro
    healthcheck:
      test: ["CMD", "nginx", "-t"]
      interval: 30s
      timeout: 10s
      retries: 3

EOF
}

#-------------------------------------------------------------------------------
# Bare Metal Installation
#-------------------------------------------------------------------------------
os_module_baremetal() {
    case "${OS_DISTRO_FAMILY}" in
        debian)
            os_baremetal_install_packages "nginx" "nginx"
            ;;
        rhel)
            os_baremetal_install_packages "nginx" "nginx"
            ;;
        arch)
            os_baremetal_install_packages "nginx" "nginx"
            ;;
        alpine)
            os_baremetal_install_packages "nginx" "nginx"
            ;;
        *)
            os_error "Bare metal installation not supported for ${OS_DISTRO_ID}"
            return 1
            ;;
    esac
    
    # Enable and start service
    os_service_enable nginx
    os_service_start nginx
    
    os_success "Nginx installed and running on port ${NGINX_HTTP_PORT}"
}

#-------------------------------------------------------------------------------
# LXC Installation
#-------------------------------------------------------------------------------
os_module_lxc() {
    local container="$1"
    
    lxc exec "$container" -- apt-get update
    lxc exec "$container" -- apt-get install -y nginx
    lxc exec "$container" -- systemctl enable nginx
    lxc exec "$container" -- systemctl start nginx
    
    os_success "Nginx installed in ${container}"
}

#-------------------------------------------------------------------------------
# Uninstall
#-------------------------------------------------------------------------------
os_module_uninstall() {
    os_pkg_remove "nginx"
}
