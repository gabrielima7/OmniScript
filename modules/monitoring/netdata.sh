#!/usr/bin/env bash
#===============================================================================
# OmniScript Module: Netdata
# Description: Real-time performance monitoring
# Maintainer: OmniScript Team
#===============================================================================

# Metadata
OS_MODULE_NAME="Netdata"
OS_MODULE_VERSION="latest"
OS_MODULE_DESCRIPTION="Real-time performance monitoring"
OS_MODULE_CATEGORY="Monitoring"
OS_MODULE_SERVICE="netdata"
OS_MODULE_DATA_DIRS=("netdata-config" "netdata-lib" "netdata-cache")

#-------------------------------------------------------------------------------
# Docker/Podman Deployment
#-------------------------------------------------------------------------------
os_module_compose() {
    local service_name="$1"
    
    cat << EOF
version: '3.8'
services:
  netdata:
    image: netdata/netdata:latest
    container_name: ${service_name}
    hostname: ${HOSTNAME:-netdata}
    pid: host
    network_mode: host
    restart: unless-stopped
    cap_add:
      - SYS_PTRACE
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined
    volumes:
      - netdata-config:/etc/netdata
      - netdata-lib:/var/lib/netdata
      - netdata-cache:/var/cache/netdata
      - /etc/passwd:/host/etc/passwd:ro
      - /etc/group:/host/etc/group:ro
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /etc/os-release:/host/etc/os-release:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro

volumes:
  netdata-config:
  netdata-lib:
  netdata-cache:
EOF
}

#-------------------------------------------------------------------------------
# Bare Metal Deployment
#-------------------------------------------------------------------------------
os_module_baremetal() {
    if os_confirm "Install Netdata via official Kickstart script?" "y"; then
        os_info "Downloading Netdata Kickstart..."
        wget -O /tmp/netdata-kickstart.sh https://my-netdata.io/kickstart.sh
        sh /tmp/netdata-kickstart.sh --non-interactive
        rm -f /tmp/netdata-kickstart.sh
        os_success "Netdata installed successfully"
    fi
}

os_module_post_install() {
    echo ""
    os_success "Netdata installed!"
    echo -e "  Dashboard: ${C_BOLD}http://${OS_DOMAIN:-localhost}:19999${C_RESET}"
    echo ""
}
