#!/usr/bin/env bash
#===============================================================================
# OmniScript - Security Hardening Library
# System hardening and security auditing
#===============================================================================

#-------------------------------------------------------------------------------
# SSH Hardening
#-------------------------------------------------------------------------------
os_harden_ssh() {
    os_require_root
    
    local sshd_config="/etc/ssh/sshd_config"
    local backup="${sshd_config}.bak.$(date +%F_%H%M%S)"
    
    os_info "Backing up SSH config to ${backup}..."
    cp "$sshd_config" "$backup"
    
    os_info "Hardening SSH configuration..."
    
    # Disable Password Authentication
    if grep -q "^PasswordAuthentication" "$sshd_config"; then
        sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' "$sshd_config"
    else
        echo "PasswordAuthentication no" >> "$sshd_config"
    fi
    
    # Disable Root Login
    if grep -q "^PermitRootLogin" "$sshd_config"; then
        sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' "$sshd_config"
    else
        echo "PermitRootLogin no" >> "$sshd_config"
    fi
    
    # Reload SSH
    if command -v systemctl &> /dev/null; then
        systemctl reload ssh
        os_success "SSH hardened and reloaded"
    else
        service ssh reload
        os_success "SSH hardened and reloaded (init.d)"
    fi
}

#-------------------------------------------------------------------------------
# Firewall Hardening (UFW)
#-------------------------------------------------------------------------------
os_harden_firewall() {
    os_require_root
    
    os_pkg_install ufw
    
    os_info "Configuring UFW..."
    
    # Reset
    ufw --force reset
    
    # Defaults
    ufw default deny incoming
    ufw default allow outgoing
    
    # Essential ports
    ufw allow 22/tcp comment 'SSH'
    ufw allow 80/tcp comment 'HTTP'
    ufw allow 443/tcp comment 'HTTPS'
    
    # Allow Docker bridge network (optional, but good for containers)
    # ufw allow in on docker0
    
    os_info "Enabling UFW..."
    ufw --force enable
    
    os_success "Firewall active and enabled on system startup"
    ufw status verbose
}

#-------------------------------------------------------------------------------
# Security Audit
#-------------------------------------------------------------------------------
os_security_audit() {
    os_banner_small
    os_menu_header "Security Audit"
    
    echo -e "  ${C_BOLD}1. Firewall Status (UFW)${C_RESET}"
    if command -v ufw &> /dev/null; then
        local ufw_status
        ufw_status=$(ufw status | grep "Status:")
        if [[ "$ufw_status" == *"active"* ]]; then
            echo -e "     ${C_GREEN}${ICON_CHECK} Active${C_RESET}"
        else
            echo -e "     ${C_RED}${ICON_CROSS} Inactive${C_RESET}"
        fi
    else
        echo -e "     ${C_RED}${ICON_CROSS} Not Installed${C_RESET}"
    fi
    echo ""
    
    echo -e "  ${C_BOLD}2. SSH Configuration${C_RESET}"
    if [[ -f "/etc/ssh/sshd_config" ]]; then
        # Password Auth
        if grep -q "^PasswordAuthentication no" "/etc/ssh/sshd_config"; then
             echo -e "     ${C_GREEN}${ICON_CHECK} Password Authentication Disabled${C_RESET}"
        else
             echo -e "     ${C_YELLOW}${ICON_WARN} Password Authentication Enabled/Default${C_RESET}"
        fi
        
        # Root Login
        if grep -q "^PermitRootLogin no" "/etc/ssh/sshd_config"; then
             echo -e "     ${C_GREEN}${ICON_CHECK} Root Login Disabled${C_RESET}"
        else
             echo -e "     ${C_YELLOW}${ICON_WARN} Root Login Enabled/Default${C_RESET}"
        fi
    fi
    echo ""
    
    echo -e "  ${C_BOLD}3. Docker Security${C_RESET}"
    if command -v docker &> /dev/null; then
        # Check if docker daemon is running as root (usually yes)
        echo -e "     ${C_CYAN}${ICON_INFO} Docker running as root (standard)${C_RESET}"
        
        # Check for userns remap (advanced)
        if grep -q "userns-remap" /etc/docker/daemon.json 2>/dev/null; then
            echo -e "     ${C_GREEN}${ICON_CHECK} User Namespace Remapping Enabled${C_RESET}"
        else
            echo -e "     ${C_DIM}○ User Namespace Remapping Disabled${C_RESET}"
        fi
    else
        echo -e "     ${C_DIM}○ Docker not installed${C_RESET}"
    fi
    echo ""
}

#-------------------------------------------------------------------------------
# Hardening Menu
#-------------------------------------------------------------------------------
os_hardening_menu() {
    while true; do
        os_clear_screen
        os_banner_small
        
        os_menu_header "Security Hardening"
        
        os_select "Select action" \
            "Run Security Audit" \
            "Configure Firewall (UFW)" \
            "Harden SSH (Disable Pass/Root)" \
            "Back"
        
        case $OS_SELECTED_INDEX in
            0) os_security_audit; read -rp "Press Enter..." ;;
            1) 
                if os_confirm "Configure UFW firewall? This may lock you out if SSH (22) is blocked." "n"; then
                    os_harden_firewall
                fi
                read -rp "Press Enter..."
                ;;
            2)
                if os_confirm "Harden SSH? This will disable password auth. Ensure you have keys!" "n"; then
                    os_harden_ssh
                fi
                read -rp "Press Enter..."
                ;;
            3|255) return ;;
        esac
    done
}
