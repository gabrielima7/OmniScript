#!/usr/bin/env bash
#===============================================================================
# OmniScript - Settings Menu Library
# Configuration and preferences management
#===============================================================================
# shellcheck disable=SC2034

#-------------------------------------------------------------------------------
# Settings Menu
#-------------------------------------------------------------------------------
os_settings_menu() {
    while true; do
        os_clear_screen
        os_banner_small
        
        os_menu_header "${EMOJI_GEAR} Settings"
        
        # Show current settings
        echo -e "  ${C_BOLD}Current Configuration:${C_RESET}"
        echo -e "    Target: ${OS_TARGET_ICONS[$OS_CURRENT_TARGET]} ${OS_TARGET_NAMES[$OS_CURRENT_TARGET]}"
        echo -e "    Domain: ${C_DIM}${OS_DOMAIN:-not set}${C_RESET}"
        echo -e "    Email: ${C_DIM}${OS_EMAIL:-not set}${C_RESET}"
        echo -e "    Auto-update: ${C_DIM}${OS_AUTO_UPDATE:-false}${C_RESET}"
        echo ""
        
        os_select "Choose setting" \
            "Change Default Target" \
            "Set Domain" \
            "Set Email (for SSL)" \
            "Toggle Auto-update" \
            "Manage Secrets" \
            "Security Hardening" \
            "Clear Caches" \
            "Reset Configuration" \
            "About OmniScript"
        
        case $OS_SELECTED_INDEX in
            0) os_settings_target ;;
            1) os_settings_domain ;;
            2) os_settings_email ;;
            3) os_settings_autoupdate ;;
            4) os_settings_secrets ;;
            5) os_hardening_menu ;;
            6) os_settings_clear_cache ;;
            7) os_settings_reset ;;
            8) os_settings_about ;;
            255) return ;;
        esac
    done
}

#-------------------------------------------------------------------------------
# Target Selection
#-------------------------------------------------------------------------------
os_settings_target() {
    os_select_target
}

#-------------------------------------------------------------------------------
# Domain Configuration
#-------------------------------------------------------------------------------
os_settings_domain() {
    local current="${OS_DOMAIN:-}"
    
    local domain
    domain=$(os_prompt "Enter default domain" "$current")
    
    if [[ -n "$domain" ]]; then
        os_config_set "OS_DOMAIN" "$domain"
        OS_DOMAIN="$domain"
        os_success "Domain set to: ${domain}"
    fi
    
    echo ""
    read -rp "Press Enter to continue..."
}

#-------------------------------------------------------------------------------
# Email Configuration
#-------------------------------------------------------------------------------
os_settings_email() {
    local current="${OS_EMAIL:-}"
    
    local email
    email=$(os_prompt "Enter email (for SSL certificates)" "$current")
    
    if [[ -n "$email" ]]; then
        os_config_set "OS_EMAIL" "$email"
        OS_EMAIL="$email"
        os_success "Email set to: ${email}"
    fi
    
    echo ""
    read -rp "Press Enter to continue..."
}

#-------------------------------------------------------------------------------
# Auto-update Toggle
#-------------------------------------------------------------------------------
os_settings_autoupdate() {
    local current="${OS_AUTO_UPDATE:-false}"
    local new_value
    
    if [[ "$current" == "true" ]]; then
        new_value="false"
    else
        new_value="true"
    fi
    
    os_config_set "OS_AUTO_UPDATE" "$new_value"
    OS_AUTO_UPDATE="$new_value"
    
    os_success "Auto-update set to: ${new_value}"
    
    echo ""
    read -rp "Press Enter to continue..."
}

#-------------------------------------------------------------------------------
# Secrets Management
#-------------------------------------------------------------------------------
os_settings_secrets() {
    while true; do
        os_clear_screen
        os_banner_small
        
        os_menu_header "Secrets Management"
        
        os_select "Choose option" \
            "List Secrets" \
            "View Secret" \
            "Add Secret" \
            "Delete Secret" \
            "Generate Password" \
            "Back"
        
        case $OS_SELECTED_INDEX in
            0)
                echo ""
                echo -e "  ${C_BOLD}Stored Secrets:${C_RESET}"
                os_secret_list | while read -r key; do
                    echo -e "    ${EMOJI_KEY} ${key}"
                done
                ;;
            1)
                local key
                key=$(os_prompt "Secret key")
                if [[ -n "$key" ]]; then
                    local value
                    value=$(os_secret_get "$key")
                    if [[ -n "$value" ]]; then
                        echo -e "  ${key}: ${C_DIM}${value}${C_RESET}"
                    else
                        os_warn "Secret not found: ${key}"
                    fi
                fi
                ;;
            2)
                local key
                key=$(os_prompt "Secret key")
                if [[ -n "$key" ]]; then
                    local value
                    value=$(os_prompt_password "Secret value")
                    if [[ -n "$value" ]]; then
                        os_secret_set "$key" "$value"
                        os_success "Secret stored: ${key}"
                    fi
                fi
                ;;
            3)
                local key
                key=$(os_prompt "Secret key to delete")
                if [[ -n "$key" ]] && os_confirm "Delete secret ${key}?" "n"; then
                    os_secret_delete "$key"
                    os_success "Secret deleted: ${key}"
                fi
                ;;
            4)
                local length
                length=$(os_prompt "Password length" "32")
                local password
                password=$(os_generate_password "$length")
                echo ""
                echo -e "  Generated password: ${C_CYAN}${password}${C_RESET}"
                
                if os_confirm "Save this password?" "n"; then
                    local key
                    key=$(os_prompt "Secret key")
                    if [[ -n "$key" ]]; then
                        os_secret_set "$key" "$password"
                        os_success "Password saved as: ${key}"
                    fi
                fi
                ;;
            5|255) return ;;
        esac
        
        echo ""
        read -rp "Press Enter to continue..."
    done
}

#-------------------------------------------------------------------------------
# Cache Management
#-------------------------------------------------------------------------------
os_settings_clear_cache() {
    os_menu_header "Clear Caches"
    
    os_select "Select cache to clear" \
        "Search cache" \
        "Tag cache" \
        "All caches" \
        "Cancel"
    
    case $OS_SELECTED_INDEX in
        0)
            os_search_clear_cache
            ;;
        1)
            os_autotag_clear_cache
            ;;
        2)
            os_search_clear_cache
            os_autotag_clear_cache
            os_success "All caches cleared"
            ;;
        3|255) return ;;
    esac
    
    echo ""
    read -rp "Press Enter to continue..."
}

#-------------------------------------------------------------------------------
# Reset Configuration
#-------------------------------------------------------------------------------
os_settings_reset() {
    if os_confirm "Reset all OmniScript configuration? This cannot be undone." "n"; then
        rm -f "${OS_CONFIG_FILE}"
        
        # Re-create default config
        os_config_set "OS_DEFAULT_TARGET" "auto"
        os_config_set "OS_AUTO_UPDATE" "false"
        
        os_success "Configuration reset to defaults"
    fi
    
    echo ""
    read -rp "Press Enter to continue..."
}

#-------------------------------------------------------------------------------
# About
#-------------------------------------------------------------------------------
os_settings_about() {
    os_clear_screen
    os_banner
    
    cat << EOF

  ${C_BOLD}OmniScript${C_RESET} v${OS_VERSION}
  Modular IaC Framework for Hybrid Deployments

  ${C_DIM}────────────────────────────────────────${C_RESET}

  ${C_BOLD}Features:${C_RESET}
    ${ICON_CHECK} Multi-target deployment (Docker, Podman, LXC, Bare Metal)
    ${ICON_CHECK} Smart search across registries and package managers
    ${ICON_CHECK} Auto-tagging with latest stable versions
    ${ICON_CHECK} Zero-downtime updates
    ${ICON_CHECK} Security by default (auto-generated passwords)
    ${ICON_CHECK} Builder Stack for complete environments
    ${ICON_CHECK} Universal backup and restore

  ${C_BOLD}Links:${C_RESET}
    ${C_CYAN}Repository:${C_RESET}  https://github.com/${OS_REPO}
    ${C_CYAN}Issues:${C_RESET}      https://github.com/${OS_REPO}/issues

  ${C_BOLD}System Info:${C_RESET}
    Distro:    ${OS_DISTRO_NAME} ${OS_DISTRO_VERSION}
    Arch:      $(os_get_arch)
    Kernel:    $(os_get_kernel_version)
    Memory:    $(os_get_memory_available_mb)MB available

  ${C_DIM}────────────────────────────────────────${C_RESET}

  Made with ${C_RED}♥${C_RESET} for the Linux community

EOF
    
    # Check for updates
    local latest
    if latest=$(os_check_for_updates); then
        echo -e "  ${C_YELLOW}${EMOJI_UPDATE} Update available: v${latest}${C_RESET}"
        echo ""
    fi
    
    read -rp "  Press Enter to continue..."
}

#-------------------------------------------------------------------------------
# Configuration File Operations
#-------------------------------------------------------------------------------
os_show_config() {
    if [[ -f "${OS_CONFIG_FILE}" ]]; then
        echo ""
        echo -e "  ${C_BOLD}Configuration File:${C_RESET} ${OS_CONFIG_FILE}"
        echo -e "  ${C_DIM}────────────────────────────────────────${C_RESET}"
        cat "${OS_CONFIG_FILE}" | while read -r line; do
            echo "  $line"
        done
        echo -e "  ${C_DIM}────────────────────────────────────────${C_RESET}"
    else
        echo "  No configuration file found"
    fi
}

os_edit_config() {
    local editor="${EDITOR:-nano}"
    
    if command -v "$editor" &> /dev/null; then
        $editor "${OS_CONFIG_FILE}"
    else
        os_warn "No editor found. Set EDITOR environment variable."
    fi
}

#-------------------------------------------------------------------------------
# Initialization Flag
#-------------------------------------------------------------------------------
OS_SETTINGS_LOADED=true
