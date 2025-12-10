#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  OmniScript - PostgreSQL Application Manifest                              ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

APP_NAME="postgres"
APP_DESCRIPTION="PostgreSQL - The World's Most Advanced Open Source Database"
APP_CATEGORY="database"
APP_WEBSITE="https://postgresql.org"
APP_SERVICE="postgresql"

# Images
DOCKER_IMAGE="postgres"
PODMAN_IMAGE="docker.io/library/postgres"
LXC_IMAGE="images:debian/bookworm"

# Packages
APT_PACKAGES="postgresql postgresql-contrib"
DNF_PACKAGES="postgresql-server postgresql-contrib"
APK_PACKAGES="postgresql postgresql-contrib"
PACMAN_PACKAGES="postgresql"
ZYPPER_PACKAGES="postgresql-server postgresql-contrib"

# Ports
PORTS=(5432)

# Volumes
VOLUMES=(
    "${OS_CONFIG_DIR}/data/postgres/data:/var/lib/postgresql/data"
)

# Environment
ENVIRONMENT=(
    "POSTGRES_USER=\${APP_DB_USER:-postgres}"
    "POSTGRES_PASSWORD=\${APP_DB_PASSWORD:-}"
    "POSTGRES_DB=\${APP_DB_NAME:-postgres}"
    "PGDATA=/var/lib/postgresql/data"
)

# Configurable
CONFIGURABLE=(
    "DB_USER:string:postgres:Database superuser name"
    "DB_PASSWORD:password::Database password (auto-generated if empty)"
    "DB_NAME:string:postgres:Default database name"
    "MAX_CONNECTIONS:number:100:Maximum connections"
)

pre_install() {
    os_log_info "Preparing PostgreSQL installation..."
    
    os_ensure_dir "${OS_CONFIG_DIR}/data/postgres/data"
    
    # Generate password if not set
    if [[ -z "${APP_DB_PASSWORD:-}" ]]; then
        APP_DB_PASSWORD=$(os_generate_password 32)
        export APP_DB_PASSWORD
    fi
}

post_install() {
    os_log_success "PostgreSQL installed!"
    os_store_credential "postgres_user" "${APP_DB_USER:-postgres}"
    os_store_credential "postgres_password" "$APP_DB_PASSWORD"
    os_store_credential "postgres_connection" "postgresql://${APP_DB_USER:-postgres}:${APP_DB_PASSWORD}@localhost:5432/${APP_DB_NAME:-postgres}"
}
