#!/usr/bin/env bash
#===============================================================================
# OmniScript - Remote Management Library
# Agentless remote execution via SSH
#===============================================================================

# Configuration
OS_REMOTE_INVENTORY="${OS_DATA_DIR:-$HOME/.omniscript}/inventory.conf"

#-------------------------------------------------------------------------------
# Core Functions
#-------------------------------------------------------------------------------
os_remote_init() {
    if [[ ! -f "$OS_REMOTE_INVENTORY" ]]; then
        mkdir -p "$(dirname "$OS_REMOTE_INVENTORY")"
        touch "$OS_REMOTE_INVENTORY"
    fi
}

os_remote_add() {
    local alias="$1"
    local connection="$2" # user@host or user@host:port
    
    if [[ -z "$alias" ]] || [[ -z "$connection" ]]; then
        os_error "Usage: os_remote_add <alias> <user@host[:port]>"
        return 1
    fi
    
    # Check if alias exists
    if grep -q "^${alias}|" "$OS_REMOTE_INVENTORY"; then
        os_error "Alias '${alias}' already exists."
        return 1
    fi
    
    # Store as alias|connection
    echo "${alias}|${connection}" >> "$OS_REMOTE_INVENTORY"
    os_success "Added remote host: ${alias} -> ${connection}"
    
    # Offer to copy ID
    if os_confirm "Copy SSH identity to ${connection}?" "y"; then
        os_info "Copying ID..."
        # Extract host and port
        local host user port
        if [[ "$connection" =~ : ]]; then
            host="${connection%:*}"
            port="${connection##*:}"
        else
            host="$connection"
            port="22"
        fi
        
        os_run "ssh-copy-id -p $port $host"
    fi
}

os_remote_list() {
    os_remote_init
    
    if [[ ! -s "$OS_REMOTE_INVENTORY" ]]; then
        echo "  No remote hosts configured."
        return
    fi
    
    echo -e "  ${C_BOLD}Remote Inventory:${C_RESET}"
    echo ""
    
    while IFS='|' read -r alias connection; do
        [[ -z "$alias" ]] && continue
        echo -e "    ${C_CYAN}●${C_RESET} ${C_BOLD}${alias}${C_RESET} (${connection})"
    done < "$OS_REMOTE_INVENTORY"
}

os_remote_remove() {
    local alias="$1"
    
    if [[ -z "$alias" ]]; then
        os_error "Alias required"
        return 1
    fi
    
    local temp_file
    temp_file=$(mktemp)
    
    grep -v "^${alias}|" "$OS_REMOTE_INVENTORY" > "$temp_file"
    mv "$temp_file" "$OS_REMOTE_INVENTORY"
    
    os_success "Removed ${alias}"
}

os_remote_get() {
    local alias="$1"
    grep "^${alias}|" "$OS_REMOTE_INVENTORY" | cut -d'|' -f2
}

os_remote_exec() {
    local alias="$1"
    shift
    local cmd="$*"
    
    local connection
    connection=$(os_remote_get "$alias")
    
    if [[ -z "$connection" ]]; then
        os_error "Unknown remote host: ${alias}"
        return 1
    fi
    
    # Parse connection for port
    local host user port args
    if [[ "$connection" =~ : ]]; then
        host="${connection%:*}"
        port="${connection##*:}"
        args="-p $port"
    else
        host="$connection"
        args=""
    fi
    
    os_info "Executing on ${alias} (${host})..."
    
    # Execute SSH
    # We use -t to force pseudo-terminal for TUI applications if needed
    ssh -t $args "$host" "export OS_IS_REMOTE=true; $cmd"
}

#-------------------------------------------------------------------------------
# Interactive Menu
#-------------------------------------------------------------------------------
os_remote_menu() {
    while true; do
        os_clear_screen
        os_banner_small
        
        os_menu_header "Remote Management"
        
        os_remote_list
        echo ""
        
        os_select "Remote Action" \
            "Connect / Shell" \
            "Execute Command" \
            "Add Host" \
            "Remove Host" \
            "Back"
            
        case $OS_SELECTED_INDEX in
            0)
                local alias
                alias=$(os_prompt "Host alias to connect")
                [[ -n "$alias" ]] && os_remote_exec "$alias" "bash -l"
                ;;
            1)
                local alias
                alias=$(os_prompt "Host alias")
                if [[ -n "$alias" ]]; then
                    local cmd
                    cmd=$(os_prompt "Command to run")
                    [[ -n "$cmd" ]] && os_remote_exec "$alias" "$cmd"
                fi
                ;;
            2)
                local alias conn
                alias=$(os_prompt "New alias (e.g. prod)")
                conn=$(os_prompt "Connection (user@host:port)")
                [[ -n "$alias" ]] && [[ -n "$conn" ]] && os_remote_add "$alias" "$conn"
                ;;
            3)
                local alias
                alias=$(os_prompt "Alias to remove")
                [[ -n "$alias" ]] && os_remote_remove "$alias"
                ;;
            4|255) return ;;
        esac
        
        echo ""
        read -rp "Press Enter to continue..."
    done
}
