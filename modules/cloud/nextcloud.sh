#!/usr/bin/env bash
#===============================================================================
# OmniScript Module: Nextcloud
# Description: A safe home for all your data
# Maintainer: OmniScript Team
#===============================================================================

# Metadata
OS_MODULE_NAME="Nextcloud"
OS_MODULE_VERSION="28.0.2"
OS_MODULE_DESCRIPTION="A safe home for all your data"
OS_MODULE_CATEGORY="Cloud & Storage"
OS_MODULE_SERVICE="nextcloud"
OS_MODULE_DATA_DIRS=("nextcloud-data" "nextcloud-db")

#-------------------------------------------------------------------------------
# Docker/Podman Deployment
#-------------------------------------------------------------------------------
os_module_compose() {
    local service_name="$1"
    
    # Generate secure passwords
    local db_pass
    db_pass=$(os_generate_password 24)
    local redis_pass
    redis_pass=$(os_generate_password 24)
    
    os_info "Generated secure database credentials"
    
    cat << EOF
version: '3.8'

services:
  db:
    image: mariadb:10.6
    command: --transaction-isolation=READ-COMMITTED --log-bin=binlog --binlog-format=ROW
    restart: unless-stopped
    volumes:
      - nextcloud-db:/var/lib/mysql
    environment:
      - MYSQL_ROOT_PASSWORD=${db_pass}
      - MYSQL_PASSWORD=${db_pass}
      - MYSQL_DATABASE=nextcloud
      - MYSQL_USER=nextcloud

  redis:
    image: redis:alpine
    container_name: nextcloud-redis
    command: redis-server --requirepass ${redis_pass}
    restart: unless-stopped

  app:
    image: nextcloud:${OS_MODULE_VERSION}
    container_name: ${service_name}
    restart: unless-stopped
    ports:
      - 8080:80
    links:
      - db
      - redis
    volumes:
      - nextcloud-data:/var/www/html
    environment:
      - MYSQL_PASSWORD=${db_pass}
      - MYSQL_DATABASE=nextcloud
      - MYSQL_USER=nextcloud
      - MYSQL_HOST=db
      - REDIS_HOST=redis
      - REDIS_HOST_PASSWORD=${redis_pass}
    depends_on:
      - db
      - redis

volumes:
  nextcloud-db:
  nextcloud-data:
EOF
}

os_module_post_install() {
    echo ""
    os_success "Nextcloud installed!"
    echo -e "  Access: ${C_BOLD}http://${OS_DOMAIN:-localhost}:8080${C_RESET}"
    echo -e "  ${C_DIM}Note: First setup will take a few minutes.${C_RESET}"
    echo ""
}
