#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  OmniScript - Backup Module                                                ║
# ║  Universal backup and restore for all targets                              ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

[[ -n "${_OS_MODULE_BACKUP_LOADED:-}" ]] && return 0
readonly _OS_MODULE_BACKUP_LOADED=1

# Backup an application
os_backup_app() {
    local app_name="$1"
    local output_dir="${2:-${OS_CONFIG[BACKUP_DIR]:-/var/backups/omniscript}}"
    
    os_log_header "Backup: $app_name"
    
    os_ensure_dir "$output_dir"
    
    # Detect which target was used
    local track_file="${OS_CONFIG_DIR}/installed.json"
    local target=""
    
    if [[ -f "$track_file" ]]; then
        target=$(grep "\"app\":\"${app_name}\"" "$track_file" | grep -oP '"target":"\K[^"]+' | head -1)
    fi
    
    if [[ -z "$target" ]]; then
        os_log_warn "Could not detect target for $app_name"
        
        local targets=("docker" "podman" "lxc" "baremetal")
        local choice
        choice=$(os_select "Select target type" "${targets[@]}")
        target="${targets[$choice]}"
    fi
    
    os_log_info "Target: $target"
    
    # Load manifest if exists
    local manifest="${OS_APPS_DIR}/${app_name}/manifest.sh"
    [[ -f "$manifest" ]] && source "$manifest"
    
    # Load adapter and perform backup
    APP_NAME="$app_name"
    source "${OS_ADAPTERS_DIR}/${target}.sh"
    adapter_backup
}

# Restore from backup
os_restore_app() {
    local backup_file="$1"
    
    if [[ -z "$backup_file" ]]; then
        # List available backups
        local backup_dir="${OS_CONFIG[BACKUP_DIR]:-/var/backups/omniscript}"
        
        if [[ ! -d "$backup_dir" ]]; then
            os_log_error "No backup directory found"
            return 1
        fi
        
        os_log_header "Available Backups"
        
        local backups=()
        while IFS= read -r -d '' file; do
            backups+=("$(basename "$file")")
        done < <(find "$backup_dir" -name "*.tar.gz" -print0 | sort -z)
        
        if [[ ${#backups[@]} -eq 0 ]]; then
            os_log_warn "No backups found in $backup_dir"
            return 1
        fi
        
        local choice
        choice=$(os_select "Select backup to restore" "${backups[@]}")
        backup_file="${backup_dir}/${backups[$choice]}"
    fi
    
    if [[ ! -f "$backup_file" ]]; then
        os_log_error "Backup file not found: $backup_file"
        return 1
    fi
    
    # Detect target from filename
    local target=""
    if [[ "$backup_file" == *"_docker_"* ]]; then
        target="docker"
    elif [[ "$backup_file" == *"_podman_"* ]]; then
        target="podman"
    elif [[ "$backup_file" == *"_lxc_"* ]]; then
        target="lxc"
    elif [[ "$backup_file" == *"_baremetal_"* ]]; then
        target="baremetal"
    else
        local targets=("docker" "podman" "lxc" "baremetal")
        local choice
        choice=$(os_select "Select target type" "${targets[@]}")
        target="${targets[$choice]}"
    fi
    
    os_log_info "Restoring from $backup_file (target: $target)"
    
    if ! os_confirm "Proceed with restore?"; then
        return 1
    fi
    
    source "${OS_ADAPTERS_DIR}/${target}.sh"
    adapter_restore "$backup_file"
}

# List all backups
os_list_backups() {
    local backup_dir="${OS_CONFIG[BACKUP_DIR]:-/var/backups/omniscript}"
    
    os_log_header "Backups"
    
    if [[ ! -d "$backup_dir" ]]; then
        os_log_warn "Backup directory does not exist: $backup_dir"
        return 0
    fi
    
    local headers=("FILE" "SIZE" "DATE")
    local rows=()
    
    while IFS= read -r -d '' file; do
        local filename size date
        filename=$(basename "$file")
        size=$(du -h "$file" | cut -f1)
        date=$(stat -c %y "$file" | cut -d'.' -f1)
        rows+=("${filename}|${size}|${date}")
    done < <(find "$backup_dir" -name "*.tar.gz" -print0 | sort -z)
    
    if [[ ${#rows[@]} -eq 0 ]]; then
        os_log_info "No backups found"
    else
        os_table headers rows
    fi
}

# Schedule automatic backup
os_schedule_backup() {
    local app_name="$1"
    local schedule="${2:-0 2 * * *}"  # Default: 2 AM daily
    
    os_require_root
    
    local cron_job="${schedule} ${OS_SCRIPT_DIR}/omniscript.sh backup ${app_name}"
    
    # Add to crontab
    (crontab -l 2>/dev/null | grep -v "omniscript.sh backup ${app_name}"; echo "$cron_job") | crontab -
    
    os_log_success "Scheduled backup for $app_name: $schedule"
}

# Clean old backups
os_cleanup_backups() {
    local days="${1:-30}"
    local backup_dir="${OS_CONFIG[BACKUP_DIR]:-/var/backups/omniscript}"
    
    os_log_info "Cleaning backups older than $days days..."
    
    local count
    count=$(find "$backup_dir" -name "*.tar.gz" -mtime +"$days" | wc -l)
    
    if [[ $count -gt 0 ]]; then
        find "$backup_dir" -name "*.tar.gz" -mtime +"$days" -delete
        os_log_success "Removed $count old backups"
    else
        os_log_info "No old backups to remove"
    fi
}
