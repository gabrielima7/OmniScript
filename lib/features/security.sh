#!/usr/bin/env bash
#===============================================================================
# OmniScript - Security Library
# Password generation, secrets management, and security hardening
#===============================================================================
# shellcheck disable=SC2034

#-------------------------------------------------------------------------------
# Security Configuration
#-------------------------------------------------------------------------------
OS_SECRETS_DIR="${OS_DATA_DIR}/.secrets"
OS_SECRETS_FILE="${OS_SECRETS_DIR}/secrets.enc"
OS_PASSWORD_LENGTH="${OS_PASSWORD_LENGTH:-32}"

#-------------------------------------------------------------------------------
# Password Generation
#-------------------------------------------------------------------------------
os_generate_password() {
    local length="${1:-$OS_PASSWORD_LENGTH}"
    local charset="${2:-A-Za-z0-9!@#$%^&*()_+-=}"
    
    local password
    
    # Try multiple methods for password generation
    if command -v openssl &> /dev/null; then
        password=$(openssl rand -base64 48 | tr -d '/+=' | cut -c1-"$length")
    elif [[ -r /dev/urandom ]]; then
        password=$(tr -dc "$charset" < /dev/urandom 2>/dev/null | head -c"$length")
    elif command -v pwgen &> /dev/null; then
        password=$(pwgen -s "$length" 1)
    else
        # Fallback: use $RANDOM (less secure but works everywhere)
        local chars="$charset"
        password=""
        for ((i=0; i<length; i++)); do
            password+="${chars:$((RANDOM % ${#chars})):1}"
        done
    fi
    
    echo "$password"
}

os_generate_password_alnum() {
    os_generate_password "${1:-32}" "A-Za-z0-9"
}

os_generate_password_simple() {
    os_generate_password "${1:-16}" "a-z0-9"
}

os_generate_uuid() {
    if command -v uuidgen &> /dev/null; then
        uuidgen
    elif [[ -r /proc/sys/kernel/random/uuid ]]; then
        cat /proc/sys/kernel/random/uuid
    else
        # Fallback: generate pseudo-UUID
        printf '%04x%04x-%04x-%04x-%04x-%04x%04x%04x\n' \
            $RANDOM $RANDOM $RANDOM \
            $((RANDOM & 0x0fff | 0x4000)) \
            $((RANDOM & 0x3fff | 0x8000)) \
            $RANDOM $RANDOM $RANDOM
    fi
}

#-------------------------------------------------------------------------------
# Secrets Management
#-------------------------------------------------------------------------------
os_secrets_init() {
    mkdir -p "${OS_SECRETS_DIR}"
    chmod 700 "${OS_SECRETS_DIR}"
    
    if [[ ! -f "${OS_SECRETS_FILE}" ]]; then
        echo "{}" > "${OS_SECRETS_FILE}"
        chmod 600 "${OS_SECRETS_FILE}"
    fi
}

os_secret_set() {
    local key="$1"
    local value="$2"
    
    os_secrets_init
    
    # If gpg is available, encrypt; otherwise store with basic protection
    if command -v gpg &> /dev/null && [[ -n "${OS_GPG_KEY:-}" ]]; then
        local temp_file
        temp_file=$(mktemp)
        
        if [[ -f "${OS_SECRETS_FILE}" ]]; then
            gpg --quiet --decrypt "${OS_SECRETS_FILE}" 2>/dev/null > "$temp_file" || echo "{}" > "$temp_file"
        else
            echo "{}" > "$temp_file"
        fi
        
        if command -v jq &> /dev/null; then
            jq --arg key "$key" --arg val "$value" '.[$key] = $val' "$temp_file" | \
                gpg --quiet --encrypt --recipient "${OS_GPG_KEY}" > "${OS_SECRETS_FILE}"
        fi
        
        rm -f "$temp_file"
    else
        # Basic file-based storage (not encrypted but restricted)
        if command -v jq &> /dev/null; then
            local temp_file
            temp_file=$(mktemp)
            jq --arg key "$key" --arg val "$value" '.[$key] = $val' "${OS_SECRETS_FILE}" > "$temp_file"
            mv "$temp_file" "${OS_SECRETS_FILE}"
            chmod 600 "${OS_SECRETS_FILE}"
        else
            # Fallback: simple key=value
            echo "${key}=${value}" >> "${OS_SECRETS_FILE}"
            chmod 600 "${OS_SECRETS_FILE}"
        fi
    fi
}

os_secret_get() {
    local key="$1"
    local default="${2:-}"
    
    if [[ ! -f "${OS_SECRETS_FILE}" ]]; then
        echo "$default"
        return
    fi
    
    local value
    
    if command -v gpg &> /dev/null && [[ -n "${OS_GPG_KEY:-}" ]]; then
        value=$(gpg --quiet --decrypt "${OS_SECRETS_FILE}" 2>/dev/null | jq -r --arg key "$key" '.[$key] // empty')
    elif command -v jq &> /dev/null; then
        value=$(jq -r --arg key "$key" '.[$key] // empty' "${OS_SECRETS_FILE}" 2>/dev/null)
    else
        value=$(grep "^${key}=" "${OS_SECRETS_FILE}" 2>/dev/null | cut -d'=' -f2-)
    fi
    
    echo "${value:-$default}"
}

os_secret_delete() {
    local key="$1"
    
    if [[ ! -f "${OS_SECRETS_FILE}" ]]; then
        return
    fi
    
    if command -v jq &> /dev/null; then
        local temp_file
        temp_file=$(mktemp)
        jq --arg key "$key" 'del(.[$key])' "${OS_SECRETS_FILE}" > "$temp_file"
        mv "$temp_file" "${OS_SECRETS_FILE}"
        chmod 600 "${OS_SECRETS_FILE}"
    fi
}

os_secret_list() {
    if [[ ! -f "${OS_SECRETS_FILE}" ]]; then
        return
    fi
    
    if command -v jq &> /dev/null; then
        jq -r 'keys[]' "${OS_SECRETS_FILE}" 2>/dev/null
    fi
}

#-------------------------------------------------------------------------------
# Auto Password for Deployments
#-------------------------------------------------------------------------------
os_get_or_create_password() {
    local key="$1"
    local length="${2:-$OS_PASSWORD_LENGTH}"
    
    local existing
    existing=$(os_secret_get "$key")
    
    if [[ -n "$existing" ]]; then
        echo "$existing"
    else
        local new_password
        new_password=$(os_generate_password "$length")
        os_secret_set "$key" "$new_password"
        echo "$new_password"
    fi
}

#-------------------------------------------------------------------------------
# Security Checks
#-------------------------------------------------------------------------------
os_check_permissions() {
    local path="$1"
    local expected="${2:-600}"
    
    local actual
    actual=$(stat -c %a "$path" 2>/dev/null || stat -f %OLp "$path" 2>/dev/null)
    
    if [[ "$actual" != "$expected" ]]; then
        os_warn "Insecure permissions on ${path}: ${actual} (expected ${expected})"
        return 1
    fi
    return 0
}

os_harden_file() {
    local path="$1"
    local mode="${2:-600}"
    
    chmod "$mode" "$path"
    os_debug "Hardened ${path} with mode ${mode}"
}

os_harden_directory() {
    local path="$1"
    local mode="${2:-700}"
    
    chmod "$mode" "$path"
    os_debug "Hardened ${path} with mode ${mode}"
}

#-------------------------------------------------------------------------------
# SSL/TLS Helpers
#-------------------------------------------------------------------------------
os_generate_self_signed_cert() {
    local domain="${1:-localhost}"
    local days="${2:-365}"
    local output_dir="${3:-${OS_DATA_DIR}/certs}"
    
    mkdir -p "$output_dir"
    
    local key_file="${output_dir}/${domain}.key"
    local cert_file="${output_dir}/${domain}.crt"
    
    os_require_command openssl || return 1
    
    os_info "Generating self-signed certificate for ${domain}..."
    
    openssl req -x509 -nodes -days "$days" -newkey rsa:2048 \
        -keyout "$key_file" \
        -out "$cert_file" \
        -subj "/CN=${domain}" \
        -addext "subjectAltName=DNS:${domain},DNS:*.${domain},IP:127.0.0.1" \
        2>/dev/null
    
    chmod 600 "$key_file"
    chmod 644 "$cert_file"
    
    os_success "Certificate generated: ${cert_file}"
    echo "$cert_file"
}

os_generate_dhparam() {
    local bits="${1:-2048}"
    local output_file="${2:-${OS_DATA_DIR}/certs/dhparam.pem}"
    
    os_require_command openssl || return 1
    
    local dir
    dir=$(dirname "$output_file")
    mkdir -p "$dir"
    
    os_info "Generating DH parameters (${bits} bits, this may take a while)..."
    
    openssl dhparam -out "$output_file" "$bits" 2>/dev/null &
    local pid=$!
    os_spinner $pid "Generating DH parameters..."
    wait $pid
    
    chmod 644 "$output_file"
    
    os_success "DH parameters generated: ${output_file}"
    echo "$output_file"
}

#-------------------------------------------------------------------------------
# Validation
#-------------------------------------------------------------------------------
os_validate_password_strength() {
    local password="$1"
    local min_length="${2:-12}"
    
    local score=0
    local issues=()
    
    # Length check
    if [[ ${#password} -ge $min_length ]]; then
        ((score++))
    else
        issues+=("Password too short (minimum ${min_length} characters)")
    fi
    
    # Uppercase
    if [[ "$password" =~ [A-Z] ]]; then
        ((score++))
    else
        issues+=("Missing uppercase letter")
    fi
    
    # Lowercase
    if [[ "$password" =~ [a-z] ]]; then
        ((score++))
    else
        issues+=("Missing lowercase letter")
    fi
    
    # Numbers
    if [[ "$password" =~ [0-9] ]]; then
        ((score++))
    else
        issues+=("Missing number")
    fi
    
    # Special characters
    if [[ "$password" =~ [^A-Za-z0-9] ]]; then
        ((score++))
    else
        issues+=("Missing special character")
    fi
    
    if [[ $score -ge 4 ]]; then
        return 0
    else
        for issue in "${issues[@]}"; do
            os_warn "$issue"
        done
        return 1
    fi
}

#-------------------------------------------------------------------------------
# Initialization Flag
#-------------------------------------------------------------------------------
OS_SECURITY_LOADED=true
