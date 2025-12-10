#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                              OmniScript                                    ║
# ║         Modular IaC Framework for Hybrid Deployments                       ║
# ║                                                                            ║
# ║  Targets: Docker | Podman | LXC | Bare Metal                               ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
#
# Usage: ./omniscript.sh [command] [options]
#        curl -sSL https://raw.githubusercontent.com/.../install.sh | bash
#
# Author: OmniScript Contributors
# License: MIT
# shellcheck disable=SC1091

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════
# Constants & Globals
# ═══════════════════════════════════════════════════════════════════════════

readonly OS_VERSION="0.1.0"
readonly OS_NAME="OmniScript"

# Determine script directory (works even when sourced via curl)
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    OS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    OS_SCRIPT_DIR="${OS_INSTALL_DIR:-/opt/omniscript}"
fi
readonly OS_SCRIPT_DIR

readonly OS_LIB_DIR="${OS_SCRIPT_DIR}/lib"
readonly OS_ADAPTERS_DIR="${OS_SCRIPT_DIR}/adapters"
readonly OS_MODULES_DIR="${OS_SCRIPT_DIR}/modules"
readonly OS_APPS_DIR="${OS_SCRIPT_DIR}/apps"
readonly OS_PKG_DIR="${OS_SCRIPT_DIR}/pkg"

# Global config paths
readonly OS_CONFIG_DIR="${OS_CONFIG_DIR:-${HOME}/.config/omniscript}"
readonly OS_GLOBAL_CONF="${OS_CONFIG_DIR}/global.conf"
readonly OS_LOG_FILE="${OS_CONFIG_DIR}/omniscript.log"
readonly OS_CACHE_DIR="${OS_CONFIG_DIR}/cache"

# ═══════════════════════════════════════════════════════════════════════════
# Library Loading
# ═══════════════════════════════════════════════════════════════════════════

os_load_libraries() {
    local libs=(
        "core"
        "logger"
        "ui"
        "config"
        "security"
    )
    
    for lib in "${libs[@]}"; do
        local lib_path="${OS_LIB_DIR}/${lib}.sh"
        if [[ -f "$lib_path" ]]; then
            # shellcheck source=/dev/null
            source "$lib_path"
        else
            echo "❌ Error: Required library not found: ${lib_path}" >&2
            exit 1
        fi
    done
}

# ═══════════════════════════════════════════════════════════════════════════
# CLI Argument Parser
# ═══════════════════════════════════════════════════════════════════════════

os_show_help() {
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════════════╗
║                              OmniScript                                    ║
║         Modular IaC Framework for Hybrid Deployments                       ║
╚═══════════════════════════════════════════════════════════════════════════╝

USAGE:
    omniscript [COMMAND] [OPTIONS]

COMMANDS:
    install <app>       Install an application
    search <query>      Search for packages/images across all sources
    info                Show system information
    update              Check and update container images
    backup              Backup applications and data
    restore             Restore from backup
    stack               Build a complete stack (DB + Backend + Frontend)
    list                List installed applications
    remove <app>        Remove an application

OPTIONS:
    -t, --target <target>   Target platform: docker|podman|lxc|baremetal
    -c, --config <file>     Use custom config file
    -v, --verbose           Enable verbose output
    -y, --yes               Auto-confirm all prompts
    -h, --help              Show this help message
    --version               Show version

EXAMPLES:
    omniscript install nginx -t docker
    omniscript search postgres
    omniscript stack --db postgres --backend python --frontend react
    omniscript backup nginx --output /backups/
    omniscript update --all

EOF
}

os_show_version() {
    echo "${OS_NAME} v${OS_VERSION}"
}

os_parse_args() {
    OS_COMMAND=""
    OS_TARGET=""
    OS_CONFIG_FILE=""
    OS_VERBOSE=false
    OS_YES=false
    OS_APP=""
    OS_QUERY=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            install|search|info|update|backup|restore|stack|list|remove)
                OS_COMMAND="$1"
                shift
                # Get app name or query if present
                if [[ $# -gt 0 && ! "$1" =~ ^- ]]; then
                    if [[ "$OS_COMMAND" == "search" ]]; then
                        OS_QUERY="$1"
                    else
                        OS_APP="$1"
                    fi
                    shift
                fi
                ;;
            -t|--target)
                OS_TARGET="$2"
                shift 2
                ;;
            -c|--config)
                OS_CONFIG_FILE="$2"
                shift 2
                ;;
            -v|--verbose)
                OS_VERBOSE=true
                shift
                ;;
            -y|--yes)
                OS_YES=true
                shift
                ;;
            -h|--help)
                os_show_help
                exit 0
                ;;
            --version)
                os_show_version
                exit 0
                ;;
            *)
                echo "❌ Unknown option: $1" >&2
                os_show_help
                exit 1
                ;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════════════════════
# Command Handlers
# ═══════════════════════════════════════════════════════════════════════════

os_cmd_install() {
    if [[ -z "${OS_APP:-}" ]]; then
        os_log_error "No application specified"
        os_log_info "Usage: omniscript install <app>"
        return 1
    fi
    
    os_banner "Installing ${OS_APP}"
    
    # Check if target is specified, otherwise ask
    if [[ -z "${OS_TARGET:-}" ]]; then
        OS_TARGET=$(os_select_target)
    fi
    
    # Verify target runtime is installed
    os_ensure_runtime_installed "$OS_TARGET"
    
    # Load application manifest
    local manifest="${OS_APPS_DIR}/${OS_APP}/manifest.sh"
    if [[ ! -f "$manifest" ]]; then
        os_log_error "Application '${OS_APP}' not found"
        os_log_info "Use 'omniscript search ${OS_APP}' to find available packages"
        return 1
    fi
    
    # Source manifest and run installation
    # shellcheck source=/dev/null
    source "$manifest"
    
    # Load appropriate adapter
    os_load_adapter "$OS_TARGET"
    
    # Run pre-install hook if defined
    if declare -f pre_install &>/dev/null; then
        pre_install
    fi
    
    # Ask for configuration if needed
    os_configure_app "$OS_APP"
    
    # Execute installation
    adapter_install
    
    # Run post-install hook if defined
    if declare -f post_install &>/dev/null; then
        post_install
    fi
    
    os_installation_summary
}

os_cmd_search() {
    if [[ -z "${OS_QUERY:-}" ]]; then
        os_log_error "No search query specified"
        os_log_info "Usage: omniscript search <query>"
        return 1
    fi
    
    os_banner "Searching: ${OS_QUERY}"
    
    # Load search module
    source "${OS_MODULES_DIR}/search.sh"
    
    os_unified_search "$OS_QUERY"
}

os_cmd_info() {
    # Load sysinfo module
    source "${OS_MODULES_DIR}/sysinfo.sh"
    
    os_show_system_info
}

os_cmd_update() {
    os_banner "Update Manager"
    
    # Load updater module
    source "${OS_MODULES_DIR}/updater.sh"
    
    os_check_updates
}

os_cmd_backup() {
    if [[ -z "${OS_APP:-}" ]]; then
        os_log_error "No application specified"
        os_log_info "Usage: omniscript backup <app>"
        return 1
    fi
    
    # Load backup module
    source "${OS_MODULES_DIR}/backup.sh"
    
    os_backup_app "$OS_APP"
}

os_cmd_restore() {
    # Load backup module
    source "${OS_MODULES_DIR}/backup.sh"
    
    os_restore_app "$OS_APP"
}

os_cmd_stack() {
    os_banner "Builder Stack"
    
    # Load builder module
    source "${OS_MODULES_DIR}/builder.sh"
    
    os_build_stack
}

os_cmd_list() {
    os_banner "Installed Applications"
    
    os_list_installed
}

os_cmd_remove() {
    if [[ -z "${OS_APP:-}" ]]; then
        os_log_error "No application specified"
        os_log_info "Usage: omniscript remove <app>"
        return 1
    fi
    
    # Load appropriate adapter based on how app was installed
    os_remove_app "$OS_APP"
}

# ═══════════════════════════════════════════════════════════════════════════
# Interactive Menu
# ═══════════════════════════════════════════════════════════════════════════

os_interactive_menu() {
    os_banner
    
    while true; do
        echo ""
        os_log_info "What would you like to do?"
        echo ""
        
        local options=(
            "📦 Install Application"
            "🔍 Search Packages/Images"
            "ℹ️  System Info"
            "🔄 Update Containers/Images"
            "💾 Backup & Restore"
            "🏗️  Builder Stack"
            "📋 List Installed Apps"
            "🗑️  Remove Application"
            "⚙️  Global Settings"
            "🚪 Exit"
        )
        
        local choice
        choice=$(os_menu "Main Menu" "${options[@]}")
        
        case "$choice" in
            0) os_interactive_install ;;
            1) os_interactive_search ;;
            2) os_cmd_info ;;
            3) os_cmd_update ;;
            4) os_interactive_backup ;;
            5) os_cmd_stack ;;
            6) os_cmd_list ;;
            7) os_interactive_remove ;;
            8) os_interactive_settings ;;
            9) 
                os_log_success "Goodbye! 👋"
                exit 0
                ;;
        esac
    done
}

os_interactive_install() {
    # First, select target
    OS_TARGET=$(os_select_target)
    os_ensure_runtime_installed "$OS_TARGET"
    
    # Then, search for app or show available
    echo ""
    os_log_info "Enter application name (or press Enter to browse):"
    read -r -p "▶ " app_name
    
    if [[ -z "$app_name" ]]; then
        # Show available apps
        os_browse_apps
    else
        OS_APP="$app_name"
        os_cmd_install
    fi
}

os_interactive_search() {
    echo ""
    os_log_info "Enter search query:"
    read -r -p "🔍 " OS_QUERY
    
    if [[ -n "$OS_QUERY" ]]; then
        os_cmd_search
    fi
}

os_interactive_backup() {
    local options=(
        "💾 Create Backup"
        "📥 Restore Backup"
        "🔙 Back"
    )
    
    local choice
    choice=$(os_menu "Backup & Restore" "${options[@]}")
    
    case "$choice" in
        0)
            echo ""
            os_log_info "Enter application name to backup:"
            read -r -p "▶ " OS_APP
            os_cmd_backup
            ;;
        1)
            echo ""
            os_log_info "Enter backup file path:"
            read -r -p "▶ " backup_path
            os_cmd_restore "$backup_path"
            ;;
        2) return ;;
    esac
}

os_interactive_remove() {
    echo ""
    os_log_info "Enter application name to remove:"
    read -r -p "▶ " OS_APP
    
    if [[ -n "$OS_APP" ]]; then
        os_cmd_remove
    fi
}

os_interactive_settings() {
    source "${OS_MODULES_DIR}/settings.sh" 2>/dev/null || {
        os_log_warn "Settings module not yet implemented"
    }
}

# ═══════════════════════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════════════════════

os_select_target() {
    local targets=(
        "🐳 Docker"
        "🦭 Podman"
        "📦 LXC/LXD"
        "🖥️  Bare Metal"
    )
    
    local choice
    choice=$(os_menu "Select Target Platform" "${targets[@]}")
    
    case "$choice" in
        0) echo "docker" ;;
        1) echo "podman" ;;
        2) echo "lxc" ;;
        3) echo "baremetal" ;;
    esac
}

os_ensure_runtime_installed() {
    local target="$1"
    
    case "$target" in
        docker)
            if ! command -v docker &>/dev/null; then
                os_log_warn "Docker is not installed"
                if os_confirm "Would you like to install Docker now?"; then
                    os_install_docker
                else
                    os_log_error "Docker is required for this operation"
                    exit 1
                fi
            fi
            ;;
        podman)
            if ! command -v podman &>/dev/null; then
                os_log_warn "Podman is not installed"
                if os_confirm "Would you like to install Podman now?"; then
                    os_install_podman
                else
                    os_log_error "Podman is required for this operation"
                    exit 1
                fi
            fi
            ;;
        lxc)
            if ! command -v lxc &>/dev/null && ! command -v lxd &>/dev/null; then
                os_log_warn "LXC/LXD is not installed"
                if os_confirm "Would you like to install LXD now?"; then
                    os_install_lxd
                else
                    os_log_error "LXC/LXD is required for this operation"
                    exit 1
                fi
            fi
            ;;
        baremetal)
            # No runtime needed for bare metal
            ;;
    esac
}

os_load_adapter() {
    local target="$1"
    local adapter_path="${OS_ADAPTERS_DIR}/${target}.sh"
    
    if [[ -f "$adapter_path" ]]; then
        # shellcheck source=/dev/null
        source "$adapter_path"
    else
        os_log_error "Adapter not found: ${target}"
        exit 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# Main Entry Point
# ═══════════════════════════════════════════════════════════════════════════

main() {
    # Create config directory if needed
    mkdir -p "$OS_CONFIG_DIR" "$OS_CACHE_DIR"
    
    # Load core libraries
    os_load_libraries
    
    # Load global configuration
    os_load_config
    
    # Parse command line arguments
    os_parse_args "$@"
    
    # Route to appropriate command or show interactive menu
    if [[ -z "${OS_COMMAND:-}" ]]; then
        os_interactive_menu
    else
        case "$OS_COMMAND" in
            install) os_cmd_install ;;
            search)  os_cmd_search ;;
            info)    os_cmd_info ;;
            update)  os_cmd_update ;;
            backup)  os_cmd_backup ;;
            restore) os_cmd_restore ;;
            stack)   os_cmd_stack ;;
            list)    os_cmd_list ;;
            remove)  os_cmd_remove ;;
            *)
                os_log_error "Unknown command: ${OS_COMMAND}"
                os_show_help
                exit 1
                ;;
        esac
    fi
}

# Run main function
main "$@"
