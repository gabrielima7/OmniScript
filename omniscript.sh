#!/usr/bin/env bash
#===============================================================================
#
#   ██████╗ ███╗   ███╗███╗   ██╗██╗███████╗ ██████╗██████╗ ██╗██████╗ ████████╗
#  ██╔═══██╗████╗ ████║████╗  ██║██║██╔════╝██╔════╝██╔══██╗██║██╔══██╗╚══██╔══╝
#  ██║   ██║██╔████╔██║██╔██╗ ██║██║███████╗██║     ██████╔╝██║██████╔╝   ██║   
#  ██║   ██║██║╚██╔╝██║██║╚██╗██║██║╚════██║██║     ██╔══██╗██║██╔═══╝    ██║   
#  ╚██████╔╝██║ ╚═╝ ██║██║ ╚████║██║███████║╚██████╗██║  ██║██║██║        ██║   
#   ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═══╝╚═╝╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝╚═╝        ╚═╝   
#
#  Modular IaC Framework for Hybrid Deployments
#  https://github.com/gabrielima7/OmniScript
#
#===============================================================================
# shellcheck disable=SC1091,SC2034

set -euo pipefail

#-------------------------------------------------------------------------------
# Version & Constants
#-------------------------------------------------------------------------------
readonly OS_VERSION="1.0.0"
readonly OS_NAME="OmniScript"
readonly OS_REPO="gabrielima7/OmniScript"
readonly OS_BRANCH="main"

#-------------------------------------------------------------------------------
# Directory Detection
#-------------------------------------------------------------------------------
# Determine script location (works with curl | bash)
if [[ -n "${BASH_SOURCE[0]:-}" ]] && [[ -f "${BASH_SOURCE[0]}" ]]; then
    OS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    # Running via curl | bash - use temp install or /opt
    OS_SCRIPT_DIR="${OS_INSTALL_DIR:-/opt/omniscript}"
fi

readonly OS_SCRIPT_DIR
readonly OS_LIB_DIR="${OS_SCRIPT_DIR}/lib"
readonly OS_MODULES_DIR="${OS_SCRIPT_DIR}/modules"
readonly OS_CONFIG_DIR="${OS_SCRIPT_DIR}/config"
readonly OS_DATA_DIR="${HOME}/.omniscript"
readonly OS_CONFIG_FILE="${OS_DATA_DIR}/config.conf"
readonly OS_LOG_FILE="${OS_DATA_DIR}/omniscript.log"

#-------------------------------------------------------------------------------
# Early Setup
#-------------------------------------------------------------------------------
mkdir -p "${OS_DATA_DIR}"

#-------------------------------------------------------------------------------
# Core Library Loading
#-------------------------------------------------------------------------------
load_library() {
    local lib_path="$1"
    if [[ -f "${lib_path}" ]]; then
        # shellcheck source=/dev/null
        source "${lib_path}"
    else
        echo "ERROR: Required library not found: ${lib_path}" >&2
        exit 1
    fi
}

# Load core libraries in order
load_library "${OS_LIB_DIR}/core/utils.sh"
load_library "${OS_LIB_DIR}/core/ui.sh"
load_library "${OS_LIB_DIR}/core/distro.sh"
load_library "${OS_LIB_DIR}/core/targets.sh"

# Load feature libraries
load_library "${OS_LIB_DIR}/features/search.sh"
load_library "${OS_LIB_DIR}/features/security.sh"
load_library "${OS_LIB_DIR}/features/backup.sh"
load_library "${OS_LIB_DIR}/features/autotag.sh"
load_library "${OS_LIB_DIR}/features/update.sh"

# Load menu libraries
load_library "${OS_LIB_DIR}/menus/main.sh"
load_library "${OS_LIB_DIR}/menus/builder.sh"
load_library "${OS_LIB_DIR}/menus/settings.sh"

#-------------------------------------------------------------------------------
# Signal Handling
#-------------------------------------------------------------------------------
cleanup() {
    os_cursor_show
    echo ""
    os_log "INFO" "OmniScript terminated"
    exit 0
}

trap cleanup SIGINT SIGTERM

#-------------------------------------------------------------------------------
# Initialization
#-------------------------------------------------------------------------------
os_init() {
    # Load user configuration
    if [[ -f "${OS_CONFIG_FILE}" ]]; then
        # shellcheck source=/dev/null
        source "${OS_CONFIG_FILE}"
    fi
    
    # Detect distribution
    os_detect_distro
    
    # Detect available targets
    os_detect_targets
    
    # Initialize logging
    os_log "INFO" "OmniScript v${OS_VERSION} starting..."
    os_log "INFO" "Detected: ${OS_DISTRO_NAME} ${OS_DISTRO_VERSION}"
    os_log "INFO" "Available targets: ${OS_AVAILABLE_TARGETS[*]:-none}"
}

#-------------------------------------------------------------------------------
# CLI Argument Parsing
#-------------------------------------------------------------------------------
show_help() {
    cat << EOF
${OS_NAME} v${OS_VERSION} - Modular IaC Framework for Hybrid Deployments

Usage: $(basename "$0") [OPTIONS] [COMMAND]

Commands:
    install <module>        Install a module
    remove <module>         Remove a module
    search <term>           Search for applications/images
    backup <target>         Backup a deployment
    restore <backup>        Restore from backup
    update                  Update OmniScript
    
Options:
    -t, --target <target>   Set deployment target (docker|podman|lxc|baremetal)
    -c, --config <file>     Use alternate config file
    -y, --yes               Skip confirmation prompts
    -v, --verbose           Enable verbose logging
    -h, --help              Show this help message
    --version               Show version information

Examples:
    $(basename "$0")                           # Launch interactive TUI
    $(basename "$0") install nginx             # Install nginx module
    $(basename "$0") -t docker install redis   # Install redis on Docker
    $(basename "$0") search postgres           # Search for postgres

For more information: https://github.com/${OS_REPO}
EOF
}

show_version() {
    echo "${OS_NAME} v${OS_VERSION}"
}

parse_args() {
    OS_TARGET="${OS_DEFAULT_TARGET:-auto}"
    OS_CONFIG_OVERRIDE=""
    OS_SKIP_CONFIRM=false
    OS_VERBOSE=false
    OS_COMMAND=""
    OS_COMMAND_ARGS=()
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -t|--target)
                OS_TARGET="$2"
                shift 2
                ;;
            -c|--config)
                OS_CONFIG_OVERRIDE="$2"
                shift 2
                ;;
            -y|--yes)
                OS_SKIP_CONFIRM=true
                shift
                ;;
            -v|--verbose)
                OS_VERBOSE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            --version)
                show_version
                exit 0
                ;;
            install|remove|search|backup|restore|update)
                OS_COMMAND="$1"
                shift
                OS_COMMAND_ARGS=("$@")
                break
                ;;
            *)
                os_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

#-------------------------------------------------------------------------------
# Command Handlers
#-------------------------------------------------------------------------------
handle_command() {
    case "${OS_COMMAND}" in
        install)
            os_install_module "${OS_COMMAND_ARGS[@]:-}"
            ;;
        remove)
            os_remove_module "${OS_COMMAND_ARGS[@]:-}"
            ;;
        search)
            os_search "${OS_COMMAND_ARGS[@]:-}"
            ;;
        backup)
            os_backup "${OS_COMMAND_ARGS[@]:-}"
            ;;
        restore)
            os_restore "${OS_COMMAND_ARGS[@]:-}"
            ;;
        update)
            os_self_update
            ;;
        "")
            # No command - launch TUI
            os_main_menu
            ;;
        *)
            os_error "Unknown command: ${OS_COMMAND}"
            exit 1
            ;;
    esac
}

#-------------------------------------------------------------------------------
# Main Entry Point
#-------------------------------------------------------------------------------
main() {
    parse_args "$@"
    
    # Load override config if specified
    if [[ -n "${OS_CONFIG_OVERRIDE}" ]] && [[ -f "${OS_CONFIG_OVERRIDE}" ]]; then
        # shellcheck source=/dev/null
        source "${OS_CONFIG_OVERRIDE}"
    fi
    
    os_init
    
    # Handle stdin for curl | bash
    if [[ ! -t 0 ]] && [[ -z "${OS_COMMAND}" ]]; then
        exec < /dev/tty
    fi
    
    handle_command
}

main "$@"
