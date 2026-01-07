#!/usr/bin/env bash
#===============================================================================
# OmniScript Module: PostgreSQL
# Deploy PostgreSQL database with Docker, Podman, or native packages
#===============================================================================
# shellcheck disable=SC2034

#-------------------------------------------------------------------------------
# Module Metadata
#-------------------------------------------------------------------------------
OS_MODULE_NAME="postgresql"
OS_MODULE_VERSION="1.0.0"
OS_MODULE_DESCRIPTION="PostgreSQL - Advanced open source relational database"
OS_MODULE_CATEGORY="databases"
OS_MODULE_SERVICE="postgresql"
OS_MODULE_DATA_DIRS="/var/lib/postgresql"
OS_MODULE_CONFIG_FILES="/etc/postgresql"

#-------------------------------------------------------------------------------
# Default Configuration
#-------------------------------------------------------------------------------
POSTGRES_VERSION="${POSTGRES_VERSION:-16}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_DB="${POSTGRES_DB:-postgres}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"

#-------------------------------------------------------------------------------
# Docker Compose
#-------------------------------------------------------------------------------
os_module_compose() {
    local password
    password=$(os_get_or_create_password "postgresql_password")
    
    local version
    version=$(os_get_best_tag "postgres" "16-alpine")
    
    cat << EOF
version: "3.8"

services:
  postgresql:
    image: postgres:${version}
    container_name: postgresql
    restart: unless-stopped
    ports:
      - "${POSTGRES_PORT}:5432"
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${password}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - postgresql-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgresql-data:
EOF
    
    os_info "PostgreSQL password: ${password}"
}

#-------------------------------------------------------------------------------
# Bare Metal Installation
#-------------------------------------------------------------------------------
os_module_baremetal() {
    local password
    password=$(os_get_or_create_password "postgresql_password")
    
    case "${OS_DISTRO_FAMILY}" in
        debian)
            os_baremetal_install_packages "postgresql" \
                "postgresql-${POSTGRES_VERSION}" \
                "postgresql-contrib-${POSTGRES_VERSION}"
            ;;
        rhel)
            # Add PostgreSQL repo for newer versions
            os_run_sudo "dnf install -y postgresql${POSTGRES_VERSION}-server postgresql${POSTGRES_VERSION}"
            os_run_sudo "postgresql-setup --initdb"
            ;;
        arch)
            os_baremetal_install_packages "postgresql" "postgresql"
            os_run_sudo "su - postgres -c 'initdb -D /var/lib/postgres/data'"
            ;;
        alpine)
            os_baremetal_install_packages "postgresql" "postgresql${POSTGRES_VERSION}"
            os_run_sudo "rc-service postgresql setup"
            ;;
        *)
            os_error "Bare metal installation not supported for ${OS_DISTRO_ID}"
            return 1
            ;;
    esac
    
    # Enable and start service
    os_service_enable postgresql
    os_service_start postgresql
    
    # Set password
    os_run_sudo "su - postgres -c \"psql -c \\\"ALTER USER postgres WITH PASSWORD '${password}';\\\"\""
    
    os_success "PostgreSQL installed with password: ${password}"
}

#-------------------------------------------------------------------------------
# LXC Installation
#-------------------------------------------------------------------------------
os_module_lxc() {
    local container="$1"
    
    os_info "Installing PostgreSQL in LXC container ${container}..."
    
    lxc exec "$container" -- apt-get update
    lxc exec "$container" -- apt-get install -y postgresql postgresql-contrib
    lxc exec "$container" -- systemctl enable postgresql
    lxc exec "$container" -- systemctl start postgresql
    
    os_success "PostgreSQL installed in ${container}"
}

#-------------------------------------------------------------------------------
# Uninstall
#-------------------------------------------------------------------------------
os_module_uninstall() {
    case "${OS_DISTRO_FAMILY}" in
        debian)
            os_pkg_remove "postgresql*"
            ;;
        rhel)
            os_pkg_remove "postgresql*"
            ;;
        arch)
            os_pkg_remove "postgresql"
            ;;
        alpine)
            os_pkg_remove "postgresql*"
            ;;
    esac
    
    os_warn "Data directory /var/lib/postgresql not removed. Delete manually if needed."
}
