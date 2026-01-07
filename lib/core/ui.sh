#!/usr/bin/env bash
#===============================================================================
# OmniScript - UI Library
# Terminal User Interface components with hacker-chic aesthetics
#===============================================================================
# shellcheck disable=SC2034

#-------------------------------------------------------------------------------
# Color Definitions
#-------------------------------------------------------------------------------
# Basic Colors
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_DIM='\033[2m'
C_ITALIC='\033[3m'
C_UNDERLINE='\033[4m'
C_BLINK='\033[5m'
C_REVERSE='\033[7m'

# Foreground Colors
C_BLACK='\033[30m'
C_RED='\033[31m'
C_GREEN='\033[32m'
C_YELLOW='\033[33m'
C_BLUE='\033[34m'
C_MAGENTA='\033[35m'
C_CYAN='\033[36m'
C_WHITE='\033[37m'

# Bright Foreground Colors
C_BRIGHT_BLACK='\033[90m'
C_BRIGHT_RED='\033[91m'
C_BRIGHT_GREEN='\033[92m'
C_BRIGHT_YELLOW='\033[93m'
C_BRIGHT_BLUE='\033[94m'
C_BRIGHT_MAGENTA='\033[95m'
C_BRIGHT_CYAN='\033[96m'
C_BRIGHT_WHITE='\033[97m'

# Background Colors
C_BG_BLACK='\033[40m'
C_BG_RED='\033[41m'
C_BG_GREEN='\033[42m'
C_BG_YELLOW='\033[43m'
C_BG_BLUE='\033[44m'
C_BG_MAGENTA='\033[45m'
C_BG_CYAN='\033[46m'
C_BG_WHITE='\033[47m'

# Theme Colors (Hacker Chic)
C_PRIMARY="${C_CYAN}"
C_SECONDARY="${C_MAGENTA}"
C_SUCCESS="${C_GREEN}"
C_WARNING="${C_YELLOW}"
C_DANGER="${C_RED}"
C_INFO="${C_BLUE}"
C_MUTED="${C_DIM}${C_WHITE}"
C_ACCENT="${C_BRIGHT_CYAN}"
C_HIGHLIGHT="${C_BG_CYAN}${C_BLACK}"

#-------------------------------------------------------------------------------
# Unicode Characters & Emojis
#-------------------------------------------------------------------------------
ICON_CHECK="✓"
ICON_CROSS="✗"
ICON_ARROW="→"
ICON_BULLET="•"
ICON_STAR="★"
ICON_CIRCLE="●"
ICON_DIAMOND="◆"
ICON_SQUARE="■"

EMOJI_ROCKET="🚀"
EMOJI_PACKAGE="📦"
EMOJI_WRENCH="🔧"
EMOJI_GEAR="⚙️"
EMOJI_SEARCH="🔍"
EMOJI_LOCK="🔒"
EMOJI_KEY="🔑"
EMOJI_FIRE="🔥"
EMOJI_SPARKLE="✨"
EMOJI_DOCKER="🐳"
EMOJI_PODMAN="🦭"
EMOJI_LXC="📦"
EMOJI_METAL="🖥️"
EMOJI_DATABASE="🗄️"
EMOJI_WEB="🌐"
EMOJI_CODE="💻"
EMOJI_SUCCESS="✅"
EMOJI_ERROR="❌"
EMOJI_WARNING="⚠️"
EMOJI_INFO="ℹ️"
EMOJI_BUILDER="🏗️"
EMOJI_BACKUP="💾"
EMOJI_UPDATE="🔄"

#-------------------------------------------------------------------------------
# Terminal Control
#-------------------------------------------------------------------------------
os_term_width() {
    tput cols 2>/dev/null || echo 80
}

os_term_height() {
    tput lines 2>/dev/null || echo 24
}

os_cursor_hide() {
    printf '\033[?25l'
}

os_cursor_show() {
    printf '\033[?25h'
}

os_cursor_save() {
    printf '\033[s'
}

os_cursor_restore() {
    printf '\033[u'
}

os_cursor_move() {
    local row="$1"
    local col="$2"
    printf '\033[%d;%dH' "$row" "$col"
}

os_clear_screen() {
    printf '\033[2J\033[H'
}

os_clear_line() {
    printf '\033[2K\r'
}

#-------------------------------------------------------------------------------
# ASCII Art Banners
#-------------------------------------------------------------------------------
os_banner() {
    local width
    width=$(os_term_width)
    
    echo -e "${C_CYAN}"
    if [[ $width -ge 80 ]]; then
        cat << 'EOF'
   ██████╗ ███╗   ███╗███╗   ██╗██╗███████╗ ██████╗██████╗ ██╗██████╗ ████████╗
  ██╔═══██╗████╗ ████║████╗  ██║██║██╔════╝██╔════╝██╔══██╗██║██╔══██╗╚══██╔══╝
  ██║   ██║██╔████╔██║██╔██╗ ██║██║███████╗██║     ██████╔╝██║██████╔╝   ██║   
  ██║   ██║██║╚██╔╝██║██║╚██╗██║██║╚════██║██║     ██╔══██╗██║██╔═══╝    ██║   
  ╚██████╔╝██║ ╚═╝ ██║██║ ╚████║██║███████║╚██████╗██║  ██║██║██║        ██║   
   ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═══╝╚═╝╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝╚═╝        ╚═╝   
EOF
    else
        cat << 'EOF'
  ╔═══════════════════════════╗
  ║     O M N I S C R I P T   ║
  ╚═══════════════════════════╝
EOF
    fi
    echo -e "${C_RESET}"
    echo -e "  ${C_MUTED}Modular IaC Framework for Hybrid Deployments${C_RESET}"
    echo -e "  ${C_MUTED}v${OS_VERSION}${C_RESET}"
    echo ""
}

os_banner_small() {
    echo -e "${C_CYAN}${C_BOLD}╔═══ OmniScript v${OS_VERSION} ═══╗${C_RESET}"
}

#-------------------------------------------------------------------------------
# Box Drawing
#-------------------------------------------------------------------------------
os_box() {
    local title="$1"
    local content="$2"
    local width="${3:-60}"
    
    local inner_width=$((width - 4))
    local title_len=${#title}
    local padding_left=$(( (inner_width - title_len) / 2 ))
    local padding_right=$(( inner_width - title_len - padding_left ))
    
    echo -e "${C_PRIMARY}╔$(printf '═%.0s' $(seq 1 $((width-2))))╗${C_RESET}"
    echo -e "${C_PRIMARY}║${C_RESET} $(printf '%*s' $padding_left '')${C_BOLD}${title}${C_RESET}$(printf '%*s' $padding_right '') ${C_PRIMARY}║${C_RESET}"
    echo -e "${C_PRIMARY}╠$(printf '═%.0s' $(seq 1 $((width-2))))╣${C_RESET}"
    
    while IFS= read -r line; do
        local line_len=${#line}
        local line_padding=$((inner_width - line_len))
        echo -e "${C_PRIMARY}║${C_RESET} ${line}$(printf '%*s' $line_padding '') ${C_PRIMARY}║${C_RESET}"
    done <<< "$content"
    
    echo -e "${C_PRIMARY}╚$(printf '═%.0s' $(seq 1 $((width-2))))╝${C_RESET}"
}

os_separator() {
    local width
    width=$(os_term_width)
    echo -e "${C_DIM}$(printf '─%.0s' $(seq 1 $width))${C_RESET}"
}

os_separator_double() {
    local width
    width=$(os_term_width)
    echo -e "${C_PRIMARY}$(printf '═%.0s' $(seq 1 $width))${C_RESET}"
}

#-------------------------------------------------------------------------------
# Status Messages
#-------------------------------------------------------------------------------
os_print_status() {
    local status="$1"
    local message="$2"
    
    case "$status" in
        success) echo -e "${C_SUCCESS}${EMOJI_SUCCESS} ${message}${C_RESET}" ;;
        error)   echo -e "${C_DANGER}${EMOJI_ERROR} ${message}${C_RESET}" ;;
        warning) echo -e "${C_WARNING}${EMOJI_WARNING} ${message}${C_RESET}" ;;
        info)    echo -e "${C_INFO}${EMOJI_INFO} ${message}${C_RESET}" ;;
        *)       echo -e "${message}" ;;
    esac
}

os_success() { os_print_status "success" "$1"; }
os_print_error() { os_print_status "error" "$1"; }
os_print_warning() { os_print_status "warning" "$1"; }
os_print_info() { os_print_status "info" "$1"; }

#-------------------------------------------------------------------------------
# Progress Indicators
#-------------------------------------------------------------------------------
os_spinner() {
    local pid="$1"
    local message="${2:-Processing...}"
    local spinchars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    
    os_cursor_hide
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${C_CYAN}%s${C_RESET} %s" "${spinchars:$i:1}" "$message"
        i=$(( (i + 1) % ${#spinchars} ))
        sleep 0.1
    done
    printf "\r${C_CLEAR_LINE}"
    os_cursor_show
}

os_progress_bar() {
    local current="$1"
    local total="$2"
    local width="${3:-50}"
    local message="${4:-}"
    
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    local bar=""
    [[ $filled -gt 0 ]] && bar+=$(printf '█%.0s' $(seq 1 $filled))
    [[ $empty -gt 0 ]] && bar+=$(printf '░%.0s' $(seq 1 $empty))
    
    printf "\r${C_CYAN}[%s]${C_RESET} %3d%% %s" "$bar" "$percent" "$message"
}

os_task_start() {
    local message="$1"
    echo -ne "${C_CYAN}${ICON_CIRCLE}${C_RESET} ${message}..."
}

os_task_done() {
    echo -e "\r${C_SUCCESS}${ICON_CHECK}${C_RESET} $1"
}

os_task_fail() {
    echo -e "\r${C_DANGER}${ICON_CROSS}${C_RESET} $1"
}

#-------------------------------------------------------------------------------
# Menu System
#-------------------------------------------------------------------------------
os_menu_header() {
    local title="$1"
    echo ""
    echo -e "  ${C_PRIMARY}${C_BOLD}${title}${C_RESET}"
    echo -e "  ${C_DIM}$(printf '─%.0s' $(seq 1 ${#title}))${C_RESET}"
    echo ""
}

os_menu_item() {
    local index="$1"
    local icon="$2"
    local label="$3"
    local description="${4:-}"
    
    if [[ -n "$description" ]]; then
        echo -e "  ${C_CYAN}[${index}]${C_RESET} ${icon} ${C_BOLD}${label}${C_RESET} ${C_DIM}- ${description}${C_RESET}"
    else
        echo -e "  ${C_CYAN}[${index}]${C_RESET} ${icon} ${label}"
    fi
}

os_menu_divider() {
    echo ""
}

os_menu_footer() {
    echo ""
    echo -e "  ${C_DIM}[q] Quit  [b] Back${C_RESET}"
    echo ""
}

# Numbered selection menu - most reliable for curl | bash
os_select() {
    local prompt="${1:-Select an option}"
    shift
    local options=("$@")
    local selected=""
    
    echo ""
    for i in "${!options[@]}"; do
        echo -e "  ${C_CYAN}[$((i+1))]${C_RESET} ${options[$i]}"
    done
    echo ""
    
    while true; do
        echo -ne "  ${C_PRIMARY}${prompt}${C_RESET} ${C_DIM}(1-${#options[@]}, q=quit):${C_RESET} "
        read -r selection
        
        if [[ "$selection" == "q" ]] || [[ "$selection" == "Q" ]]; then
            return 255
        fi
        
        if [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 ]] && [[ "$selection" -le ${#options[@]} ]]; then
            selected="${options[$((selection-1))]}"
            OS_SELECTED_INDEX=$((selection-1))
            OS_SELECTED_VALUE="$selected"
            return 0
        fi
        
        echo -e "  ${C_WARNING}Invalid selection. Try again.${C_RESET}"
    done
}

# Arrow-key menu (for interactive terminals)
os_select_arrow() {
    local prompt="$1"
    shift
    local options=("$@")
    local selected=0
    local key=""
    
    os_cursor_hide
    trap 'os_cursor_show' RETURN
    
    while true; do
        os_clear_screen
        os_banner_small
        echo ""
        echo -e "  ${C_BOLD}${prompt}${C_RESET}"
        echo ""
        
        for i in "${!options[@]}"; do
            if [[ $i -eq $selected ]]; then
                echo -e "  ${C_HIGHLIGHT} ${ICON_ARROW} ${options[$i]} ${C_RESET}"
            else
                echo -e "    ${options[$i]}"
            fi
        done
        
        echo ""
        echo -e "  ${C_DIM}↑/↓ Navigate  Enter: Select  q: Quit${C_RESET}"
        
        read -rsn1 key
        case "$key" in
            $'\x1b')
                read -rsn2 key
                case "$key" in
                    '[A') ((selected > 0)) && ((selected--)) ;;  # Up
                    '[B') ((selected < ${#options[@]} - 1)) && ((selected++)) ;;  # Down
                esac
                ;;
            '') # Enter
                OS_SELECTED_INDEX=$selected
                OS_SELECTED_VALUE="${options[$selected]}"
                os_cursor_show
                return 0
                ;;
            q|Q)
                os_cursor_show
                return 255
                ;;
        esac
    done
}

#-------------------------------------------------------------------------------
# Input Prompts
#-------------------------------------------------------------------------------
os_prompt() {
    local message="$1"
    local default="${2:-}"
    local result=""
    
    if [[ -n "$default" ]]; then
        echo -ne "  ${C_PRIMARY}${message}${C_RESET} ${C_DIM}[${default}]:${C_RESET} "
    else
        echo -ne "  ${C_PRIMARY}${message}:${C_RESET} "
    fi
    
    read -r result
    echo "${result:-$default}"
}

os_prompt_password() {
    local message="$1"
    local result=""
    
    echo -ne "  ${C_PRIMARY}${message}:${C_RESET} "
    read -rs result
    echo ""
    echo "$result"
}

os_confirm() {
    local message="$1"
    local default="${2:-n}"
    
    local hint="y/N"
    [[ "${default,,}" == "y" ]] && hint="Y/n"
    
    echo -ne "  ${C_WARNING}${message}${C_RESET} ${C_DIM}[${hint}]:${C_RESET} "
    read -r response
    response="${response:-$default}"
    
    [[ "${response,,}" == "y" ]] || [[ "${response,,}" == "yes" ]]
}

#-------------------------------------------------------------------------------
# Tables
#-------------------------------------------------------------------------------
os_table_header() {
    local -a columns=("$@")
    local width
    width=$(os_term_width)
    local col_width=$(( (width - 4) / ${#columns[@]} ))
    
    echo -e "${C_PRIMARY}┌$(printf '─%.0s' $(seq 1 $((width-2))))┐${C_RESET}"
    printf "${C_PRIMARY}│${C_RESET}"
    for col in "${columns[@]}"; do
        printf " ${C_BOLD}%-$((col_width-1))s${C_RESET}" "$col"
    done
    echo -e "${C_PRIMARY}│${C_RESET}"
    echo -e "${C_PRIMARY}├$(printf '─%.0s' $(seq 1 $((width-2))))┤${C_RESET}"
}

os_table_row() {
    local -a values=("$@")
    local width
    width=$(os_term_width)
    local col_width=$(( (width - 4) / ${#values[@]} ))
    
    printf "${C_PRIMARY}│${C_RESET}"
    for val in "${values[@]}"; do
        printf " %-$((col_width-1))s" "$val"
    done
    echo -e "${C_PRIMARY}│${C_RESET}"
}

os_table_footer() {
    local width
    width=$(os_term_width)
    echo -e "${C_PRIMARY}└$(printf '─%.0s' $(seq 1 $((width-2))))┘${C_RESET}"
}

#-------------------------------------------------------------------------------
# Notifications
#-------------------------------------------------------------------------------
os_notify() {
    local title="$1"
    local message="$2"
    
    # Try desktop notification first
    if command -v notify-send &> /dev/null; then
        notify-send "OmniScript: ${title}" "${message}" 2>/dev/null || true
    fi
    
    # Always show in terminal
    os_print_info "${title}: ${message}"
}

#-------------------------------------------------------------------------------
# Initialization Flag
#-------------------------------------------------------------------------------
OS_UI_LOADED=true
