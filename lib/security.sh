#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  OmniScript - Security Library                                             ║
# ║  Password generation, SSH keys, and security utilities                     ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

[[ -n "${_OS_SECURITY_LOADED:-}" ]] && return 0
readonly _OS_SECURITY_LOADED=1

# Store generated credentials
declare -A OS_CREDENTIALS=()

# Generate secure password
os_generate_password() {
    local length="${1:-32}"
    local charset="${2:-A-Za-z0-9@#%^&*}"
    
    tr -dc "$charset" < /dev/urandom | head -c "$length"
}

# Generate alphanumeric password (no special chars)
os_generate_password_alphanum() {
    local length="${1:-32}"
    tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$length"
}

# Hash password with SHA-256
os_hash_password() {
    local password="$1"
    echo -n "$password" | sha256sum | cut -d' ' -f1
}

# Generate SSH key pair
os_generate_ssh_key() {
    local key_path="${1:-$HOME/.ssh/omniscript_key}"
    local comment="${2:-omniscript@$(hostname)}"
    
    if [[ -f "$key_path" ]]; then
        os_log_warn "SSH key already exists at $key_path"
        return 0
    fi
    
    os_ensure_dir "$(dirname "$key_path")"
    
    ssh-keygen -t ed25519 -C "$comment" -f "$key_path" -N "" -q
    chmod 600 "$key_path"
    chmod 644 "${key_path}.pub"
    
    os_log_success "SSH key generated: $key_path"
    echo "$key_path"
}

# Store credential for later display
os_store_credential() {
    local name="$1"
    local value="$2"
    OS_CREDENTIALS["$name"]="$value"
}

# Get or generate password for a service
os_get_or_generate_password() {
    local service="$1"
    local env_var="APP_${service^^}_PASSWORD"
    
    local password="${!env_var:-}"
    
    if [[ -z "$password" ]]; then
        password=$(os_generate_password 32)
        os_store_credential "${service}_password" "$password"
    fi
    
    echo "$password"
}

# Display installation summary with credentials
os_installation_summary() {
    local app_name="${APP_NAME:-Application}"
    local target="${OS_TARGET:-unknown}"
    
    os_log_blank
    os_log_header "Installation Summary"
    
    echo ""
    printf '%b╭─────────────────────────────────────────────────────────────────╮%b\n' "$C_GREEN" "$C_RESET"
    printf '%b│  ✅ %s installed successfully!%*s│%b\n' "$C_GREEN" "$app_name" $((35 - ${#app_name})) "" "$C_RESET"
    printf '%b╰─────────────────────────────────────────────────────────────────╯%b\n' "$C_GREEN" "$C_RESET"
    echo ""
    
    os_log_section "Details"
    os_log_kv "Application" "$app_name"
    os_log_kv "Target" "$target"
    os_log_kv "Installed at" "$(date '+%Y-%m-%d %H:%M:%S')"
    
    # Show ports if defined
    if [[ -n "${PORTS[*]:-}" ]]; then
        os_log_section "Ports"
        for port in "${PORTS[@]}"; do
            os_log_list_item "http://localhost:${port}"
        done
    fi
    
    # Show credentials if generated
    if [[ ${#OS_CREDENTIALS[@]} -gt 0 ]]; then
        os_log_section "Credentials"
        printf '%b⚠️  Save these credentials - they won'\''t be shown again!%b\n' "$C_YELLOW" "$C_RESET"
        echo ""
        
        for key in "${!OS_CREDENTIALS[@]}"; do
            printf '  %b%s:%b %s\n' "$C_BOLD" "$key" "$C_RESET" "${OS_CREDENTIALS[$key]}"
        done
    fi
    
    os_log_blank
    os_log_hr
    os_log_blank
}

# Validate password strength
os_validate_password() {
    local password="$1"
    local min_length="${2:-8}"
    
    if [[ ${#password} -lt $min_length ]]; then
        os_log_error "Password must be at least $min_length characters"
        return 1
    fi
    
    # Check for complexity
    local has_upper has_lower has_digit has_special
    [[ "$password" =~ [A-Z] ]] && has_upper=1
    [[ "$password" =~ [a-z] ]] && has_lower=1
    [[ "$password" =~ [0-9] ]] && has_digit=1
    [[ "$password" =~ [^A-Za-z0-9] ]] && has_special=1
    
    local complexity=$((has_upper + has_lower + has_digit + has_special))
    
    if [[ $complexity -lt 3 ]]; then
        os_log_warn "Password should contain at least 3 of: uppercase, lowercase, digit, special"
        return 1
    fi
    
    return 0
}

# Secure file permissions
os_secure_file() {
    local file="$1"
    local mode="${2:-600}"
    
    if [[ -f "$file" ]]; then
        chmod "$mode" "$file"
        os_log_debug "Secured $file with mode $mode"
    fi
}

# Check if running over SSH
os_is_ssh() {
    [[ -n "${SSH_CLIENT:-}" ]] || [[ -n "${SSH_TTY:-}" ]]
}

# Get client IP
os_get_client_ip() {
    if os_is_ssh; then
        echo "${SSH_CLIENT%% *}"
    else
        hostname -I | awk '{print $1}'
    fi
}
