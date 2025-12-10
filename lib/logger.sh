#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  OmniScript - Logger Library                                               ║
# ║  Logging with colors and emojis                                            ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

[[ -n "${_OS_LOGGER_LOADED:-}" ]] && return 0
readonly _OS_LOGGER_LOADED=1

# Colors
if [[ -t 1 ]] && [[ "${TERM:-}" != "dumb" ]]; then
    OS_COLOR_ENABLED=true
else
    OS_COLOR_ENABLED=false
fi

readonly C_RESET='\033[0m' C_BOLD='\033[1m' C_DIM='\033[2m'
readonly C_RED='\033[31m' C_GREEN='\033[32m' C_YELLOW='\033[33m'
readonly C_BLUE='\033[34m' C_CYAN='\033[36m' C_BRIGHT_CYAN='\033[96m'

# Emojis
readonly E_SUCCESS="✅" E_ERROR="❌" E_WARNING="⚠️" E_INFO="ℹ️" E_DEBUG="🔧"
readonly E_ARROW="➜" E_DOCKER="🐳" E_PODMAN="🦭" E_PACKAGE="📦"

# Log levels
readonly LOG_LEVEL_DEBUG=0 LOG_LEVEL_INFO=1 LOG_LEVEL_WARN=2 LOG_LEVEL_ERROR=3 LOG_LEVEL_SUCCESS=4
OS_LOG_LEVEL="${OS_LOG_LEVEL:-$LOG_LEVEL_INFO}"
OS_LOG_TO_FILE="${OS_LOG_TO_FILE:-false}"

os_color() {
    local color="$1"; shift
    [[ "$OS_COLOR_ENABLED" == "true" ]] && printf '%b%s%b' "$color" "$*" "$C_RESET" || printf '%s' "$*"
}

_os_log() {
    local level="$1" emoji="$2" color="$3" label="$4"; shift 4
    [[ $level -lt $OS_LOG_LEVEL ]] && return 0
    local ts; ts=$(date '+%H:%M:%S')
    if [[ "$OS_COLOR_ENABLED" == "true" ]]; then
        printf '%b[%s]%b %s %b%-7s%b %s\n' "$C_DIM" "$ts" "$C_RESET" "$emoji" "$color" "$label" "$C_RESET" "$*"
    else
        printf '[%s] %s %-7s %s\n' "$ts" "$emoji" "$label" "$*"
    fi
    [[ "$OS_LOG_TO_FILE" == "true" && -n "${OS_LOG_FILE:-}" ]] && printf '[%s] %-7s %s\n' "$(date -Iseconds)" "$label" "$*" >> "$OS_LOG_FILE"
}

os_log_debug() { _os_log $LOG_LEVEL_DEBUG "$E_DEBUG" "$C_DIM" "DEBUG" "$@"; }
os_log_info() { _os_log $LOG_LEVEL_INFO "$E_INFO" "$C_BLUE" "INFO" "$@"; }
os_log_warn() { _os_log $LOG_LEVEL_WARN "$E_WARNING" "$C_YELLOW" "WARN" "$@"; }
os_log_error() { _os_log $LOG_LEVEL_ERROR "$E_ERROR" "$C_RED" "ERROR" "$@" >&2; }
os_log_success() { _os_log $LOG_LEVEL_SUCCESS "$E_SUCCESS" "$C_GREEN" "SUCCESS" "$@"; }

os_log_step() {
    local step="$1" total="$2"; shift 2
    printf '%b[%d/%d]%b %s %s\n' "$C_CYAN$C_BOLD" "$step" "$total" "$C_RESET" "$E_ARROW" "$*"
}

os_log_header() {
    local title="$1"
    echo ""
    printf '%b%s%b\n' "$C_CYAN$C_BOLD" "═══════════════════════════════════════════════════════════" "$C_RESET"
    printf '%b  %s%b\n' "$C_CYAN$C_BOLD" "$title" "$C_RESET"
    printf '%b%s%b\n' "$C_CYAN$C_BOLD" "═══════════════════════════════════════════════════════════" "$C_RESET"
    echo ""
}

os_log_section() { echo ""; printf '%b── %s ──%b\n' "$C_BRIGHT_CYAN" "$1" "$C_RESET"; }
os_log_kv() { printf '%b%s:%b %s\n' "$C_BOLD" "$1" "$C_RESET" "$2"; }
os_log_list_item() { printf '%b•%b %s\n' "$C_CYAN" "$C_RESET" "$1"; }
os_log_code() { printf '  %b$ %s%b\n' "$C_DIM" "$1" "$C_RESET"; }
os_log_hr() { printf '%b%s%b\n' "$C_DIM" "────────────────────────────────────────────────────────────" "$C_RESET"; }
os_log_blank() { echo ""; }
