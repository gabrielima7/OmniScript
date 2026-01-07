#!/usr/bin/env bash
#===============================================================================
# OmniScript - Distribution Detection Library
# Detect Linux distribution, package manager, and system characteristics
#===============================================================================
# shellcheck disable=SC2034

#-------------------------------------------------------------------------------
# Distribution Variables (populated by os_detect_distro)
#-------------------------------------------------------------------------------
OS_DISTRO_ID=""
OS_DISTRO_NAME=""
OS_DISTRO_VERSION=""
OS_DISTRO_CODENAME=""
OS_DISTRO_FAMILY=""
OS_PKG_MANAGER=""
OS_PKG_INSTALL=""
OS_PKG_UPDATE=""
OS_PKG_REMOVE=""
OS_PKG_SEARCH=""
OS_SERVICE_MANAGER=""
OS_INIT_SYSTEM=""

#-------------------------------------------------------------------------------
# Distribution Detection
#-------------------------------------------------------------------------------
os_detect_distro() {
    # Try /etc/os-release first (most modern distros)
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        OS_DISTRO_ID="${ID:-unknown}"
        OS_DISTRO_NAME="${NAME:-Unknown}"
        OS_DISTRO_VERSION="${VERSION_ID:-}"
        OS_DISTRO_CODENAME="${VERSION_CODENAME:-}"
    elif [[ -f /etc/lsb-release ]]; then
        # shellcheck source=/dev/null
        source /etc/lsb-release
        OS_DISTRO_ID="${DISTRIB_ID,,}"
        OS_DISTRO_NAME="${DISTRIB_ID}"
        OS_DISTRO_VERSION="${DISTRIB_RELEASE}"
        OS_DISTRO_CODENAME="${DISTRIB_CODENAME}"
    elif [[ -f /etc/debian_version ]]; then
        OS_DISTRO_ID="debian"
        OS_DISTRO_NAME="Debian"
        OS_DISTRO_VERSION=$(cat /etc/debian_version)
    elif [[ -f /etc/redhat-release ]]; then
        OS_DISTRO_ID="rhel"
        OS_DISTRO_NAME=$(cat /etc/redhat-release | cut -d' ' -f1)
        OS_DISTRO_VERSION=$(cat /etc/redhat-release | grep -oE '[0-9]+\.[0-9]+' | head -1)
    elif [[ -f /etc/arch-release ]]; then
        OS_DISTRO_ID="arch"
        OS_DISTRO_NAME="Arch Linux"
        OS_DISTRO_VERSION="rolling"
    elif [[ -f /etc/alpine-release ]]; then
        OS_DISTRO_ID="alpine"
        OS_DISTRO_NAME="Alpine Linux"
        OS_DISTRO_VERSION=$(cat /etc/alpine-release)
    else
        OS_DISTRO_ID="unknown"
        OS_DISTRO_NAME="Unknown"
        OS_DISTRO_VERSION=""
    fi
    
    # Normalize distro ID
    OS_DISTRO_ID="${OS_DISTRO_ID,,}"  # lowercase
    
    # Detect distro family and set package manager
    _os_set_distro_family
    _os_set_pkg_manager
    _os_detect_init_system
    
    os_debug "Detected distro: ${OS_DISTRO_NAME} ${OS_DISTRO_VERSION} (${OS_DISTRO_FAMILY})"
    os_debug "Package manager: ${OS_PKG_MANAGER}"
    os_debug "Init system: ${OS_INIT_SYSTEM}"
}

_os_set_distro_family() {
    case "${OS_DISTRO_ID}" in
        ubuntu|debian|linuxmint|pop|elementary|zorin|kali|raspbian|neon|mx)
            OS_DISTRO_FAMILY="debian"
            ;;
        fedora|rhel|centos|rocky|alma|oracle|amazon)
            OS_DISTRO_FAMILY="rhel"
            ;;
        arch|manjaro|endeavouros|garuda|artix)
            OS_DISTRO_FAMILY="arch"
            ;;
        opensuse*|suse|sles)
            OS_DISTRO_FAMILY="suse"
            ;;
        alpine)
            OS_DISTRO_FAMILY="alpine"
            ;;
        gentoo)
            OS_DISTRO_FAMILY="gentoo"
            ;;
        void)
            OS_DISTRO_FAMILY="void"
            ;;
        nixos)
            OS_DISTRO_FAMILY="nix"
            ;;
        *)
            OS_DISTRO_FAMILY="unknown"
            ;;
    esac
}

_os_set_pkg_manager() {
    case "${OS_DISTRO_FAMILY}" in
        debian)
            OS_PKG_MANAGER="apt"
            OS_PKG_UPDATE="apt update && apt upgrade -y"
            OS_PKG_INSTALL="apt install -y"
            OS_PKG_REMOVE="apt remove -y"
            OS_PKG_SEARCH="apt search"
            ;;
        rhel)
            if command -v dnf &> /dev/null; then
                OS_PKG_MANAGER="dnf"
                OS_PKG_UPDATE="dnf upgrade -y"
                OS_PKG_INSTALL="dnf install -y"
                OS_PKG_REMOVE="dnf remove -y"
                OS_PKG_SEARCH="dnf search"
            else
                OS_PKG_MANAGER="yum"
                OS_PKG_UPDATE="yum update -y"
                OS_PKG_INSTALL="yum install -y"
                OS_PKG_REMOVE="yum remove -y"
                OS_PKG_SEARCH="yum search"
            fi
            ;;
        arch)
            OS_PKG_MANAGER="pacman"
            OS_PKG_UPDATE="pacman -Syu --noconfirm"
            OS_PKG_INSTALL="pacman -S --noconfirm"
            OS_PKG_REMOVE="pacman -R --noconfirm"
            OS_PKG_SEARCH="pacman -Ss"
            ;;
        suse)
            OS_PKG_MANAGER="zypper"
            OS_PKG_UPDATE="zypper --non-interactive update"
            OS_PKG_INSTALL="zypper --non-interactive install"
            OS_PKG_REMOVE="zypper --non-interactive remove"
            OS_PKG_SEARCH="zypper search"
            ;;
        alpine)
            OS_PKG_MANAGER="apk"
            OS_PKG_UPDATE="apk update && apk upgrade"
            OS_PKG_INSTALL="apk add"
            OS_PKG_REMOVE="apk del"
            OS_PKG_SEARCH="apk search"
            ;;
        gentoo)
            OS_PKG_MANAGER="emerge"
            OS_PKG_UPDATE="emerge --sync && emerge -uDN @world"
            OS_PKG_INSTALL="emerge"
            OS_PKG_REMOVE="emerge --unmerge"
            OS_PKG_SEARCH="emerge --search"
            ;;
        void)
            OS_PKG_MANAGER="xbps"
            OS_PKG_UPDATE="xbps-install -Su"
            OS_PKG_INSTALL="xbps-install -y"
            OS_PKG_REMOVE="xbps-remove -y"
            OS_PKG_SEARCH="xbps-query -Rs"
            ;;
        nix)
            OS_PKG_MANAGER="nix"
            OS_PKG_UPDATE="nix-channel --update && nixos-rebuild switch"
            OS_PKG_INSTALL="nix-env -iA"
            OS_PKG_REMOVE="nix-env -e"
            OS_PKG_SEARCH="nix search"
            ;;
        *)
            OS_PKG_MANAGER="unknown"
            os_warn "Unknown package manager for distribution: ${OS_DISTRO_ID}"
            ;;
    esac
}

_os_detect_init_system() {
    if [[ -d /run/systemd/system ]]; then
        OS_INIT_SYSTEM="systemd"
        OS_SERVICE_MANAGER="systemctl"
    elif [[ -f /sbin/openrc ]]; then
        OS_INIT_SYSTEM="openrc"
        OS_SERVICE_MANAGER="rc-service"
    elif [[ -f /sbin/runit ]]; then
        OS_INIT_SYSTEM="runit"
        OS_SERVICE_MANAGER="sv"
    elif [[ -f /etc/init.d/rcS ]]; then
        OS_INIT_SYSTEM="sysvinit"
        OS_SERVICE_MANAGER="service"
    else
        OS_INIT_SYSTEM="unknown"
        OS_SERVICE_MANAGER="service"
    fi
}

#-------------------------------------------------------------------------------
# Package Operations
#-------------------------------------------------------------------------------
os_pkg_install() {
    local packages=("$@")
    os_log "INFO" "Installing packages: ${packages[*]}"
    
    os_run_sudo "${OS_PKG_INSTALL} ${packages[*]}"
}

os_pkg_remove() {
    local packages=("$@")
    os_log "INFO" "Removing packages: ${packages[*]}"
    
    os_run_sudo "${OS_PKG_REMOVE} ${packages[*]}"
}

os_pkg_update() {
    os_log "INFO" "Updating system packages"
    os_run_sudo "${OS_PKG_UPDATE}"
}

os_pkg_search() {
    local term="$1"
    os_run "${OS_PKG_SEARCH} ${term}"
}

os_pkg_is_installed() {
    local package="$1"
    
    case "${OS_PKG_MANAGER}" in
        apt)
            dpkg -l "$package" 2>/dev/null | grep -q "^ii"
            ;;
        dnf|yum)
            rpm -q "$package" &>/dev/null
            ;;
        pacman)
            pacman -Q "$package" &>/dev/null
            ;;
        zypper)
            zypper se -i "$package" 2>/dev/null | grep -q "^i"
            ;;
        apk)
            apk info "$package" &>/dev/null
            ;;
        *)
            command -v "$package" &>/dev/null
            ;;
    esac
}

#-------------------------------------------------------------------------------
# Service Operations
#-------------------------------------------------------------------------------
os_service_start() {
    local service="$1"
    os_log "INFO" "Starting service: ${service}"
    
    case "${OS_INIT_SYSTEM}" in
        systemd)
            os_run_sudo "systemctl start ${service}"
            ;;
        openrc)
            os_run_sudo "rc-service ${service} start"
            ;;
        runit)
            os_run_sudo "sv start ${service}"
            ;;
        *)
            os_run_sudo "service ${service} start"
            ;;
    esac
}

os_service_stop() {
    local service="$1"
    os_log "INFO" "Stopping service: ${service}"
    
    case "${OS_INIT_SYSTEM}" in
        systemd)
            os_run_sudo "systemctl stop ${service}"
            ;;
        openrc)
            os_run_sudo "rc-service ${service} stop"
            ;;
        runit)
            os_run_sudo "sv stop ${service}"
            ;;
        *)
            os_run_sudo "service ${service} stop"
            ;;
    esac
}

os_service_restart() {
    local service="$1"
    os_log "INFO" "Restarting service: ${service}"
    
    case "${OS_INIT_SYSTEM}" in
        systemd)
            os_run_sudo "systemctl restart ${service}"
            ;;
        openrc)
            os_run_sudo "rc-service ${service} restart"
            ;;
        runit)
            os_run_sudo "sv restart ${service}"
            ;;
        *)
            os_run_sudo "service ${service} restart"
            ;;
    esac
}

os_service_enable() {
    local service="$1"
    os_log "INFO" "Enabling service: ${service}"
    
    case "${OS_INIT_SYSTEM}" in
        systemd)
            os_run_sudo "systemctl enable ${service}"
            ;;
        openrc)
            os_run_sudo "rc-update add ${service} default"
            ;;
        runit)
            os_run_sudo "ln -sf /etc/sv/${service} /var/service/"
            ;;
        *)
            os_warn "Service enabling not supported on ${OS_INIT_SYSTEM}"
            ;;
    esac
}

os_service_disable() {
    local service="$1"
    os_log "INFO" "Disabling service: ${service}"
    
    case "${OS_INIT_SYSTEM}" in
        systemd)
            os_run_sudo "systemctl disable ${service}"
            ;;
        openrc)
            os_run_sudo "rc-update del ${service}"
            ;;
        runit)
            os_run_sudo "rm -f /var/service/${service}"
            ;;
        *)
            os_warn "Service disabling not supported on ${OS_INIT_SYSTEM}"
            ;;
    esac
}

os_service_status() {
    local service="$1"
    
    case "${OS_INIT_SYSTEM}" in
        systemd)
            systemctl is-active "${service}" 2>/dev/null
            ;;
        openrc)
            rc-service "${service}" status 2>/dev/null | grep -q "started"
            ;;
        runit)
            sv status "${service}" 2>/dev/null | grep -q "run"
            ;;
        *)
            service "${service}" status 2>/dev/null
            ;;
    esac
}

os_service_is_running() {
    local service="$1"
    [[ "$(os_service_status "$service")" == "active" ]]
}

#-------------------------------------------------------------------------------
# System Info
#-------------------------------------------------------------------------------
os_get_arch() {
    local arch
    arch=$(uname -m)
    
    case "$arch" in
        x86_64|amd64) echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        armv7l|armhf) echo "armhf" ;;
        armv6l) echo "armv6" ;;
        i386|i686) echo "386" ;;
        *) echo "$arch" ;;
    esac
}

os_get_kernel_version() {
    uname -r
}

os_get_hostname() {
    hostname 2>/dev/null || cat /etc/hostname 2>/dev/null || echo "localhost"
}

os_get_memory_total_mb() {
    awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo
}

os_get_memory_available_mb() {
    awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo
}

os_get_disk_free_gb() {
    local path="${1:-/}"
    df -BG "$path" 2>/dev/null | awk 'NR==2 {print int($4)}'
}

os_get_cpu_cores() {
    nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 1
}

#-------------------------------------------------------------------------------
# Initialization Flag
#-------------------------------------------------------------------------------
OS_DISTRO_LOADED=true
