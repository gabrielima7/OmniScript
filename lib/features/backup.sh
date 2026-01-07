#!/usr/bin/env bash
#===============================================================================
# OmniScript - Backup Library
# Universal backup and restore across all targets
#===============================================================================
# shellcheck disable=SC2034

#-------------------------------------------------------------------------------
# Backup Configuration
#-------------------------------------------------------------------------------
OS_BACKUP_DIR="${OS_DATA_DIR}/backups"
OS_BACKUP_RETENTION_DAYS="${OS_BACKUP_RETENTION_DAYS:-30}"
OS_BACKUP_COMPRESS="${OS_BACKUP_COMPRESS:-true}"

#-------------------------------------------------------------------------------
# Unified Backup Interface
#-------------------------------------------------------------------------------
os_backup() {
    local target="${1:-}"
    
    if [[ -z "$target" ]]; then
        os_backup_interactive
        return
    fi
    
    os_target_backup "$target"
}

os_restore() {
    local backup_file="${1:-}"
    local deployment_name="${2:-}"
    
    if [[ -z "$backup_file" ]]; then
        os_restore_interactive
        return
    fi
    
    os_target_restore "$backup_file" "$deployment_name"
}

#-------------------------------------------------------------------------------
# Backup Operations
#-------------------------------------------------------------------------------
os_create_backup() {
    local name="$1"
    local paths=("${@:2}")
    
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_file="${OS_BACKUP_DIR}/${name}_${timestamp}.tar"
    
    mkdir -p "${OS_BACKUP_DIR}"
    
    os_info "Creating backup: ${name}"
    
    # Create tar archive
    local existing_paths=()
    for path in "${paths[@]}"; do
        if [[ -e "$path" ]]; then
            existing_paths+=("$path")
        fi
    done
    
    if [[ ${#existing_paths[@]} -eq 0 ]]; then
        os_error "No valid paths to backup"
        return 1
    fi
    
    tar -cf "$backup_file" "${existing_paths[@]}" 2>/dev/null
    
    # Compress if enabled
    if [[ "${OS_BACKUP_COMPRESS}" == "true" ]]; then
        gzip "$backup_file"
        backup_file="${backup_file}.gz"
    fi
    
    # Create metadata
    local meta_file="${backup_file}.meta"
    cat > "$meta_file" << EOF
{
    "name": "${name}",
    "timestamp": "${timestamp}",
    "created_at": "$(date -Iseconds)",
    "target": "${OS_CURRENT_TARGET}",
    "distro": "${OS_DISTRO_ID}",
    "paths": $(printf '%s\n' "${paths[@]}" | jq -R . | jq -s .),
    "size": "$(du -h "$backup_file" | cut -f1)"
}
EOF
    
    os_success "Backup created: ${backup_file}"
    echo "$backup_file"
}

os_restore_backup() {
    local backup_file="$1"
    local restore_dir="${2:-/}"
    
    if [[ ! -f "$backup_file" ]]; then
        os_error "Backup file not found: ${backup_file}"
        return 1
    fi
    
    os_info "Restoring from: ${backup_file}"
    
    # Determine if compressed
    if [[ "$backup_file" == *.gz ]]; then
        tar -xzf "$backup_file" -C "$restore_dir"
    else
        tar -xf "$backup_file" -C "$restore_dir"
    fi
    
    os_success "Restore complete"
}

#-------------------------------------------------------------------------------
# Backup Listing
#-------------------------------------------------------------------------------
os_list_backups() {
    os_menu_header "Available Backups"
    
    if [[ ! -d "${OS_BACKUP_DIR}" ]]; then
        echo "  No backups found"
        return
    fi
    
    local total_size=0
    local count=0
    
    echo ""
    
    for backup_file in "${OS_BACKUP_DIR}"/*.tar.gz "${OS_BACKUP_DIR}"/*.tar; do
        if [[ -f "$backup_file" ]]; then
            local name
            name=$(basename "$backup_file")
            
            local size
            size=$(du -h "$backup_file" 2>/dev/null | cut -f1)
            
            local date
            date=$(stat -c %y "$backup_file" 2>/dev/null | cut -d' ' -f1)
            
            local meta_file="${backup_file}.meta"
            local target=""
            
            if [[ -f "$meta_file" ]] && command -v jq &> /dev/null; then
                target=$(jq -r '.target // ""' "$meta_file" 2>/dev/null)
            fi
            
            local target_icon=""
            case "$target" in
                docker) target_icon="${EMOJI_DOCKER}" ;;
                podman) target_icon="${EMOJI_PODMAN}" ;;
                lxc)    target_icon="${EMOJI_LXC}" ;;
                baremetal) target_icon="${EMOJI_METAL}" ;;
            esac
            
            echo -e "  ${EMOJI_BACKUP} ${name}"
            echo -e "     ${C_DIM}Size: ${size} | Date: ${date} ${target_icon}${C_RESET}"
            echo ""
            
            ((count++))
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        echo "  No backups found"
    else
        echo -e "  ${C_DIM}Total: ${count} backups${C_RESET}"
    fi
}

#-------------------------------------------------------------------------------
# Backup Cleanup
#-------------------------------------------------------------------------------
os_cleanup_old_backups() {
    local days="${1:-$OS_BACKUP_RETENTION_DAYS}"
    
    if [[ ! -d "${OS_BACKUP_DIR}" ]]; then
        return
    fi
    
    os_info "Cleaning backups older than ${days} days..."
    
    local count=0
    
    find "${OS_BACKUP_DIR}" -name "*.tar*" -mtime "+${days}" -type f | while read -r file; do
        rm -f "$file"
        rm -f "${file}.meta"
        os_debug "Removed: ${file}"
        ((count++))
    done
    
    os_success "Removed ${count} old backups"
}

#-------------------------------------------------------------------------------
# Interactive Backup
#-------------------------------------------------------------------------------
os_backup_interactive() {
    os_menu_header "Backup"
    
    # List deployments
    local deployments=()
    
    case "${OS_CURRENT_TARGET}" in
        docker)
            if [[ -d "${OS_DOCKER_STACKS_DIR:-}" ]]; then
                for stack in "${OS_DOCKER_STACKS_DIR}"/*/; do
                    [[ -d "$stack" ]] && deployments+=("$(basename "$stack")")
                done
            fi
            ;;
        podman)
            if [[ -d "${OS_PODMAN_STACKS_DIR:-}" ]]; then
                for stack in "${OS_PODMAN_STACKS_DIR}"/*/; do
                    [[ -d "$stack" ]] && deployments+=("$(basename "$stack")")
                done
            fi
            ;;
        lxc)
            while IFS= read -r container; do
                [[ -n "$container" ]] && deployments+=("$container")
            done < <(lxc list --format csv -c n 2>/dev/null)
            ;;
        baremetal)
            if [[ -d "${OS_BAREMETAL_DEPLOY_DIR:-}" ]]; then
                for reg in "${OS_BAREMETAL_DEPLOY_DIR}"/*.json; do
                    [[ -f "$reg" ]] && deployments+=("$(basename "$reg" .json)")
                done
            fi
            ;;
    esac
    
    if [[ ${#deployments[@]} -eq 0 ]]; then
        os_warn "No deployments found to backup"
        return 1
    fi
    
    os_select "Select deployment to backup" "${deployments[@]}"
    
    if [[ $? -eq 0 ]]; then
        os_target_backup "$OS_SELECTED_VALUE"
    fi
}

#-------------------------------------------------------------------------------
# Interactive Restore
#-------------------------------------------------------------------------------
os_restore_interactive() {
    os_menu_header "Restore"
    
    if [[ ! -d "${OS_BACKUP_DIR}" ]]; then
        os_warn "No backups found"
        return 1
    fi
    
    local backups=()
    
    for backup_file in "${OS_BACKUP_DIR}"/*.tar.gz "${OS_BACKUP_DIR}"/*.tar; do
        if [[ -f "$backup_file" ]]; then
            backups+=("$(basename "$backup_file")")
        fi
    done
    
    if [[ ${#backups[@]} -eq 0 ]]; then
        os_warn "No backups found"
        return 1
    fi
    
    os_select "Select backup to restore" "${backups[@]}"
    
    if [[ $? -eq 0 ]]; then
        local backup_path="${OS_BACKUP_DIR}/${OS_SELECTED_VALUE}"
        
        if os_confirm "Restore from ${OS_SELECTED_VALUE}?" "n"; then
            os_target_restore "$backup_path"
        fi
    fi
}

#-------------------------------------------------------------------------------
# Scheduled Backups (for cron)
#-------------------------------------------------------------------------------
os_backup_scheduled() {
    local target="$1"
    
    os_log "INFO" "Starting scheduled backup for ${target}"
    
    local backup_file
    backup_file=$(os_target_backup "$target")
    
    if [[ -n "$backup_file" ]]; then
        os_log "INFO" "Scheduled backup complete: ${backup_file}"
    else
        os_log "ERROR" "Scheduled backup failed for ${target}"
    fi
    
    # Cleanup old backups
    os_cleanup_old_backups
}

os_setup_backup_cron() {
    local target="$1"
    local schedule="${2:-0 3 * * *}"  # Default: daily at 3 AM
    
    local cron_cmd="${OS_SCRIPT_DIR}/omniscript.sh backup ${target}"
    local cron_line="${schedule} ${cron_cmd}"
    
    if os_confirm "Add backup cron job for ${target}? (${schedule})" "y"; then
        (crontab -l 2>/dev/null | grep -v "$cron_cmd"; echo "$cron_line") | crontab -
        os_success "Backup cron job added"
    fi
}

#-------------------------------------------------------------------------------
# Initialization Flag
#-------------------------------------------------------------------------------
OS_BACKUP_LOADED=true
