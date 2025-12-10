#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  OmniScript - UI Library                                                   ║
# ║  Spinners, progress bars, menus, and banners                               ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

[[ -n "${_OS_UI_LOADED:-}" ]] && return 0
readonly _OS_UI_LOADED=1

# ASCII Art Banner
os_banner() {
    local subtitle="${1:-}"
    cat << 'EOF'
   ____                  _ _____           _       _   
  / __ \                (_)  __ \         (_)     | |  
 | |  | |_ __ ___  _ __  _| (___  ___ _ __ _ _ __ | |_ 
 | |  | | '_ ` _ \| '_ \| |\___ \/ __| '__| | '_ \| __|
 | |__| | | | | | | | | | |____) \__ \ |  | | |_) | |_ 
  \____/|_| |_| |_|_| |_|_|_____/|___/_|  |_| .__/ \__|
                                            | |        
                                            |_|        
EOF
    printf '%b  Modular IaC Framework v%s%b\n' "$C_CYAN" "${OS_VERSION:-0.1.0}" "$C_RESET"
    [[ -n "$subtitle" ]] && printf '%b  %s%b\n' "$C_DIM" "$subtitle" "$C_RESET"
    echo ""
}

# Spinner (run background process)
declare -a OS_SPINNER_FRAMES=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
OS_SPINNER_PID=""

os_spinner_start() {
    local message="${1:-Loading...}"
    (
        local i=0
        while true; do
            printf '\r%b%s%b %s' "$C_CYAN" "${OS_SPINNER_FRAMES[$i]}" "$C_RESET" "$message"
            i=$(( (i + 1) % ${#OS_SPINNER_FRAMES[@]} ))
            sleep 0.1
        done
    ) &
    OS_SPINNER_PID=$!
    disown
}

os_spinner_stop() {
    if [[ -n "$OS_SPINNER_PID" ]]; then
        kill "$OS_SPINNER_PID" 2>/dev/null
        wait "$OS_SPINNER_PID" 2>/dev/null || true
        printf '\r\033[K'
        OS_SPINNER_PID=""
    fi
}

# Progress bar
os_progress_bar() {
    local current="$1" total="$2" width="${3:-40}" label="${4:-}"
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf '\r%b[' "$C_CYAN"
    printf '%0.s█' $(seq 1 $filled) 2>/dev/null
    printf '%0.s░' $(seq 1 $empty) 2>/dev/null
    printf ']%b %3d%% %s' "$C_RESET" "$percent" "$label"
    
    [[ $current -eq $total ]] && echo ""
}

# Interactive menu
os_menu() {
    local title="$1"; shift
    local options=("$@")
    local selected=0
    local key
    
    # Hide cursor
    printf '\033[?25l'
    trap 'printf "\033[?25h"' RETURN
    
    while true; do
        # Clear and print title
        printf '\033[2J\033[H'
        os_log_header "$title"
        
        # Print options
        for i in "${!options[@]}"; do
            if [[ $i -eq $selected ]]; then
                printf '%b ▶ %s%b\n' "$C_CYAN$C_BOLD" "${options[$i]}" "$C_RESET"
            else
                printf '   %s\n' "${options[$i]}"
            fi
        done
        
        echo ""
        printf '%bUse ↑↓ arrows to navigate, Enter to select%b\n' "$C_DIM" "$C_RESET"
        
        # Read key
        IFS= read -rsn1 key
        case "$key" in
            $'\x1b')
                read -rsn2 key
                case "$key" in
                    '[A') ((selected > 0)) && ((selected--)) ;;
                    '[B') ((selected < ${#options[@]} - 1)) && ((selected++)) ;;
                esac
                ;;
            '') echo "$selected"; return ;;
        esac
    done
}

# Simple select (numbered list)
os_select() {
    local title="$1"; shift
    local options=("$@")
    
    echo ""
    os_log_section "$title"
    echo ""
    
    for i in "${!options[@]}"; do
        printf '  %b[%d]%b %s\n' "$C_CYAN" "$((i + 1))" "$C_RESET" "${options[$i]}"
    done
    
    echo ""
    local choice
    while true; do
        read -r -p "$(printf '%b▶%b ' "$C_CYAN" "$C_RESET")" choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#options[@]})); then
            echo "$((choice - 1))"
            return
        fi
        os_log_warn "Please enter a number between 1 and ${#options[@]}"
    done
}

# Yes/No confirmation
os_confirm() {
    local message="${1:-Continue?}"
    local default="${2:-y}"
    
    local prompt
    [[ "$default" == "y" ]] && prompt="[Y/n]" || prompt="[y/N]"
    
    printf '%s %b%s%b ' "$message" "$C_DIM" "$prompt" "$C_RESET"
    read -r response
    
    response="${response:-$default}"
    [[ "${response,,}" =~ ^y(es)?$ ]]
}

# Text input
os_input() {
    local prompt="$1"
    local default="${2:-}"
    local result
    
    if [[ -n "$default" ]]; then
        printf '%s %b[%s]%b: ' "$prompt" "$C_DIM" "$default" "$C_RESET"
    else
        printf '%s: ' "$prompt"
    fi
    
    read -r result
    echo "${result:-$default}"
}

# Password input (hidden)
os_input_password() {
    local prompt="${1:-Password}"
    local password
    
    printf '%s: ' "$prompt"
    read -rs password
    echo ""
    echo "$password"
}

# Table display
os_table() {
    local -n headers=$1
    local -n rows=$2
    local cols=${#headers[@]}
    
    # Calculate column widths
    local -a widths=()
    for h in "${headers[@]}"; do
        widths+=("${#h}")
    done
    
    for row in "${rows[@]}"; do
        IFS='|' read -ra cells <<< "$row"
        for i in "${!cells[@]}"; do
            local len=${#cells[$i]}
            ((len > widths[i])) && widths[i]=$len
        done
    done
    
    # Print header
    printf '%b' "$C_BOLD"
    for i in "${!headers[@]}"; do
        printf '%-*s  ' "${widths[$i]}" "${headers[$i]}"
    done
    printf '%b\n' "$C_RESET"
    
    # Print separator
    for w in "${widths[@]}"; do
        printf '%*s  ' "$w" '' | tr ' ' '─'
    done
    echo ""
    
    # Print rows
    for row in "${rows[@]}"; do
        IFS='|' read -ra cells <<< "$row"
        for i in "${!cells[@]}"; do
            printf '%-*s  ' "${widths[$i]}" "${cells[$i]}"
        done
        echo ""
    done
}
