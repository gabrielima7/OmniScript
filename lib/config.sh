#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  OmniScript - Configuration Library                                        ║
# ║  Global and per-app configuration management                               ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

[[ -n "${_OS_CONFIG_LOADED:-}" ]] && return 0
readonly _OS_CONFIG_LOADED=1

# Default configuration values
declare -A OS_CONFIG=(
    [DOMAIN]="localhost"
    [EMAIL]=""
    [TIMEZONE]="UTC"
    [SMTP_HOST]=""
    [SMTP_PORT]="587"
    [SMTP_USER]=""
    [SMTP_PASS]=""
    [PROXY_HTTP]=""
    [PROXY_HTTPS]=""
    [DNS_PRIMARY]="1.1.1.1"
    [DNS_SECONDARY]="8.8.8.8"
    [DEFAULT_TARGET]="docker"
    [AUTO_UPDATE]="false"
    [BACKUP_DIR]="/var/backups/omniscript"
    [LOG_LEVEL]="info"
)

# Load configuration from file
os_load_config() {
    local config_file="${1:-$OS_GLOBAL_CONF}"
    
    if [[ -f "$config_file" ]]; then
        os_log_debug "Loading config from $config_file"
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            [[ "$key" =~ ^[[:space:]]*# ]] && continue
            [[ -z "$key" ]] && continue
            
            key=$(os_trim "$key")
            value=$(os_trim "$value")
            value="${value#\"}" ; value="${value%\"}"  # Remove quotes
            
            OS_CONFIG["$key"]="$value"
        done < "$config_file"
    fi
    
    # Export config as environment variables
    for key in "${!OS_CONFIG[@]}"; do
        export "OS_${key}=${OS_CONFIG[$key]}"
    done
}

# Save configuration to file
os_save_config() {
    local config_file="${1:-$OS_GLOBAL_CONF}"
    
    os_ensure_dir "$(dirname "$config_file")"
    
    {
        echo "# OmniScript Global Configuration"
        echo "# Generated: $(date -Iseconds)"
        echo ""
        for key in "${!OS_CONFIG[@]}"; do
            echo "${key}=\"${OS_CONFIG[$key]}\""
        done
    } > "$config_file"
    
    os_log_success "Configuration saved to $config_file"
}

# Get config value
os_config_get() {
    local key="$1"
    local default="${2:-}"
    echo "${OS_CONFIG[$key]:-$default}"
}

# Set config value
os_config_set() {
    local key="$1"
    local value="$2"
    OS_CONFIG["$key"]="$value"
    export "OS_${key}=${value}"
}

# Interactive config editor
os_config_edit() {
    os_log_header "Global Configuration"
    
    local options=(
        "🌐 Domain: ${OS_CONFIG[DOMAIN]}"
        "📧 Email: ${OS_CONFIG[EMAIL]:-not set}"
        "🕐 Timezone: ${OS_CONFIG[TIMEZONE]}"
        "📡 DNS: ${OS_CONFIG[DNS_PRIMARY]}"
        "🎯 Default Target: ${OS_CONFIG[DEFAULT_TARGET]}"
        "💾 Backup Dir: ${OS_CONFIG[BACKUP_DIR]}"
        "💾 Save & Exit"
        "🚪 Cancel"
    )
    
    while true; do
        local choice
        choice=$(os_select "Edit Configuration" "${options[@]}")
        
        case $choice in
            0) OS_CONFIG[DOMAIN]=$(os_input "Domain" "${OS_CONFIG[DOMAIN]}") ;;
            1) OS_CONFIG[EMAIL]=$(os_input "Email" "${OS_CONFIG[EMAIL]}") ;;
            2) OS_CONFIG[TIMEZONE]=$(os_input "Timezone" "${OS_CONFIG[TIMEZONE]}") ;;
            3) OS_CONFIG[DNS_PRIMARY]=$(os_input "Primary DNS" "${OS_CONFIG[DNS_PRIMARY]}") ;;
            4) 
                local targets=("docker" "podman" "lxc" "baremetal")
                local t_choice
                t_choice=$(os_select "Default Target" "${targets[@]}")
                OS_CONFIG[DEFAULT_TARGET]="${targets[$t_choice]}"
                ;;
            5) OS_CONFIG[BACKUP_DIR]=$(os_input "Backup Directory" "${OS_CONFIG[BACKUP_DIR]}") ;;
            6) os_save_config; return 0 ;;
            7) return 1 ;;
        esac
        
        # Update options display
        options=(
            "🌐 Domain: ${OS_CONFIG[DOMAIN]}"
            "📧 Email: ${OS_CONFIG[EMAIL]:-not set}"
            "🕐 Timezone: ${OS_CONFIG[TIMEZONE]}"
            "📡 DNS: ${OS_CONFIG[DNS_PRIMARY]}"
            "🎯 Default Target: ${OS_CONFIG[DEFAULT_TARGET]}"
            "💾 Backup Dir: ${OS_CONFIG[BACKUP_DIR]}"
            "💾 Save & Exit"
            "🚪 Cancel"
        )
    done
}

# Configure app-specific settings
os_configure_app() {
    local app_name="$1"
    
    # Check if app has CONFIGURABLE array defined
    if [[ -z "${CONFIGURABLE[*]:-}" ]]; then
        return 0
    fi
    
    os_log_section "Configure $app_name"
    
    if ! os_confirm "Would you like to customize settings?"; then
        os_log_info "Using default configuration"
        return 0
    fi
    
    for config_item in "${CONFIGURABLE[@]}"; do
        IFS=':' read -r key type default description <<< "$config_item"
        
        local value
        case "$type" in
            string)
                value=$(os_input "$description" "$default")
                ;;
            number)
                value=$(os_input "$description (number)" "$default")
                ;;
            bool)
                if os_confirm "$description" "${default:0:1}"; then
                    value="true"
                else
                    value="false"
                fi
                ;;
            password)
                value=$(os_input_password "$description")
                [[ -z "$value" ]] && value=$(os_generate_password)
                ;;
        esac
        
        export "APP_${key}=${value}"
    done
}

# Create example config file
os_create_example_config() {
    local example_file="${OS_SCRIPT_DIR}/global.conf.example"
    
    cat > "$example_file" << 'EOF'
# ═══════════════════════════════════════════════════════════════════════════
# OmniScript Global Configuration
# ═══════════════════════════════════════════════════════════════════════════

# === General ===
DOMAIN="example.com"
EMAIL="admin@example.com"
TIMEZONE="America/Sao_Paulo"

# === Network ===
DNS_PRIMARY="1.1.1.1"
DNS_SECONDARY="8.8.8.8"

# === SMTP (for notifications) ===
SMTP_HOST=""
SMTP_PORT="587"
SMTP_USER=""
SMTP_PASS=""

# === Proxy ===
PROXY_HTTP=""
PROXY_HTTPS=""

# === Defaults ===
DEFAULT_TARGET="docker"
AUTO_UPDATE="false"
BACKUP_DIR="/var/backups/omniscript"
LOG_LEVEL="info"
EOF
    
    os_log_success "Created example config at $example_file"
}
