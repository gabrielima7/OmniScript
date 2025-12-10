#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  OmniScript - System Info Module                                           ║
# ║  Display system information and installed runtimes                         ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

[[ -n "${_OS_MODULE_SYSINFO_LOADED:-}" ]] && return 0
readonly _OS_MODULE_SYSINFO_LOADED=1

os_show_system_info() {
    os_log_header "System Information"
    
    # OS Info
    os_log_section "Operating System"
    os_log_kv "Distribution" "$OS_PRETTY_NAME"
    os_log_kv "Architecture" "$OS_ARCH"
    os_log_kv "Kernel" "$(uname -r)"
    os_log_kv "Hostname" "$(hostname)"
    os_log_kv "Package Manager" "$OS_PKG_MANAGER"
    
    # Hardware
    os_log_section "Hardware"
    os_log_kv "CPU" "$(grep -c ^processor /proc/cpuinfo) cores"
    os_log_kv "CPU Model" "$(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
    os_log_kv "Memory" "$(free -h | awk '/^Mem:/ {print $2}') total, $(free -h | awk '/^Mem:/ {print $7}') available"
    os_log_kv "Disk" "$(df -h / | awk 'NR==2 {print $4}') available on /"
    
    # Network
    os_log_section "Network"
    local default_ip
    default_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    os_log_kv "IP Address" "${default_ip:-N/A}"
    os_log_kv "Default Gateway" "$(ip route | awk '/default/ {print $3}' | head -1)"
    
    # Container Runtimes
    os_log_section "Container Runtimes"
    
    # Docker
    if command -v docker &>/dev/null; then
        local docker_version
        docker_version=$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')
        local docker_status="✅ Installed (v${docker_version})"
        if docker info &>/dev/null 2>&1; then
            local containers
            containers=$(docker ps -q 2>/dev/null | wc -l)
            docker_status+=" - ${containers} containers running"
        else
            docker_status+=" - daemon not accessible"
        fi
        os_log_kv "🐳 Docker" "$docker_status"
    else
        os_log_kv "🐳 Docker" "❌ Not installed"
    fi
    
    # Podman
    if command -v podman &>/dev/null; then
        local podman_version
        podman_version=$(podman --version 2>/dev/null | awk '{print $3}')
        local containers
        containers=$(podman ps -q 2>/dev/null | wc -l)
        os_log_kv "🦭 Podman" "✅ Installed (v${podman_version}) - ${containers} containers"
    else
        os_log_kv "🦭 Podman" "❌ Not installed"
    fi
    
    # LXC/LXD
    if command -v lxc &>/dev/null; then
        local lxd_version
        lxd_version=$(lxc version 2>/dev/null | head -1)
        local containers
        containers=$(lxc list -c n --format csv 2>/dev/null | wc -l)
        os_log_kv "📦 LXC/LXD" "✅ Installed (${lxd_version}) - ${containers} containers"
    else
        os_log_kv "📦 LXC/LXD" "❌ Not installed"
    fi
    
    # OmniScript Info
    os_log_section "OmniScript"
    os_log_kv "Version" "${OS_VERSION:-0.1.0}"
    os_log_kv "Config Dir" "${OS_CONFIG_DIR}"
    os_log_kv "Install Dir" "${OS_SCRIPT_DIR}"
    
    # Installed apps count
    local track_file="${OS_CONFIG_DIR}/installed.json"
    if [[ -f "$track_file" ]]; then
        local app_count
        app_count=$(wc -l < "$track_file")
        os_log_kv "Managed Apps" "$app_count"
    fi
    
    echo ""
}

# Quick check for specific runtime
os_check_runtime() {
    local runtime="$1"
    
    case "$runtime" in
        docker)
            command -v docker &>/dev/null && docker info &>/dev/null
            ;;
        podman)
            command -v podman &>/dev/null
            ;;
        lxc|lxd)
            command -v lxc &>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

# List available runtimes
os_list_runtimes() {
    local available=()
    
    os_check_runtime docker && available+=("docker")
    os_check_runtime podman && available+=("podman")
    os_check_runtime lxc && available+=("lxc")
    available+=("baremetal")  # Always available
    
    printf '%s\n' "${available[@]}"
}
