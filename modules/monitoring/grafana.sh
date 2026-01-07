#!/usr/bin/env bash
#===============================================================================
# OmniScript Module: Grafana
# Deploy Grafana visualization platform
#===============================================================================
# shellcheck disable=SC2034

#-------------------------------------------------------------------------------
# Module Metadata
#-------------------------------------------------------------------------------
OS_MODULE_NAME="grafana"
OS_MODULE_VERSION="1.0.0"
OS_MODULE_DESCRIPTION="Grafana - Analytics and visualization platform"
OS_MODULE_CATEGORY="monitoring"
OS_MODULE_SERVICE="grafana-server"

#-------------------------------------------------------------------------------
# Default Configuration
#-------------------------------------------------------------------------------
GRAFANA_PORT="${GRAFANA_PORT:-3000}"

#-------------------------------------------------------------------------------
# Docker Compose
#-------------------------------------------------------------------------------
os_module_compose() {
    local admin_password
    admin_password=$(os_get_or_create_password "grafana_admin" 16)
    
    local version
    version=$(os_get_best_tag "grafana/grafana" "latest")
    
    cat << EOF
version: "3.8"

services:
  grafana:
    image: grafana/grafana:${version}
    container_name: grafana
    restart: unless-stopped
    ports:
      - "${GRAFANA_PORT}:3000"
    environment:
      GF_SECURITY_ADMIN_USER: admin
      GF_SECURITY_ADMIN_PASSWORD: ${admin_password}
      GF_INSTALL_PLUGINS: grafana-clock-panel,grafana-simple-json-datasource
    volumes:
      - grafana-data:/var/lib/grafana
      - ./provisioning:/etc/grafana/provisioning
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:3000/api/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  grafana-data:
EOF
    
    os_info "Grafana admin password: ${admin_password}"
    os_info "Access at: http://localhost:${GRAFANA_PORT}"
}

#-------------------------------------------------------------------------------
# Bare Metal Installation
#-------------------------------------------------------------------------------
os_module_baremetal() {
    case "${OS_DISTRO_FAMILY}" in
        debian)
            # Add Grafana repository
            os_run_sudo "apt-get install -y apt-transport-https software-properties-common"
            os_run_sudo "curl -fsSL https://packages.grafana.com/gpg.key | gpg --dearmor -o /usr/share/keyrings/grafana.gpg"
            echo "deb [signed-by=/usr/share/keyrings/grafana.gpg] https://packages.grafana.com/oss/deb stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
            os_run_sudo "apt-get update"
            os_pkg_install "grafana"
            ;;
        rhel)
            cat << 'EOF' | sudo tee /etc/yum.repos.d/grafana.repo
[grafana]
name=grafana
baseurl=https://packages.grafana.com/oss/rpm
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://packages.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF
            os_pkg_install "grafana"
            ;;
        *)
            os_error "Bare metal installation not supported for ${OS_DISTRO_ID}"
            os_info "Please use Docker target instead"
            return 1
            ;;
    esac
    
    os_service_enable grafana-server
    os_service_start grafana-server
    
    os_success "Grafana installed and running on port ${GRAFANA_PORT}"
    os_info "Default login: admin / admin"
}
