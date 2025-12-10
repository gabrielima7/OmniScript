#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  OmniScript - Smart Search Module                                          ║
# ║  Unified search across Docker Hub, Quay.io, and package managers           ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

[[ -n "${_OS_MODULE_SEARCH_LOADED:-}" ]] && return 0
readonly _OS_MODULE_SEARCH_LOADED=1

# Search Docker Hub
os_search_dockerhub() {
    local query="$1"
    local limit="${2:-10}"
    
    os_log_section "🐳 Docker Hub"
    
    local url="https://hub.docker.com/v2/search/repositories/?query=${query}&page_size=${limit}"
    local results
    results=$(curl -sSL "$url" 2>/dev/null)
    
    if [[ -z "$results" ]]; then
        os_log_warn "Could not fetch Docker Hub results"
        return 1
    fi
    
    echo "$results" | grep -oP '"repo_name":"\K[^"]+' | while read -r repo; do
        local stars pulls
        stars=$(echo "$results" | grep -oP "\"repo_name\":\"${repo}\".*?\"star_count\":\K[0-9]+" | head -1)
        pulls=$(echo "$results" | grep -oP "\"repo_name\":\"${repo}\".*?\"pull_count\":\K[0-9]+" | head -1)
        
        # Get latest stable tag
        local tag
        tag=$(os_get_latest_tag_dockerhub "$repo")
        
        printf "  %b%-30s%b ⭐ %-6s 📥 %-10s 🏷️  %s\n" "$C_CYAN" "$repo" "$C_RESET" "${stars:-0}" "${pulls:-0}" "${tag:-latest}"
    done
}

# Get latest stable tag from Docker Hub
os_get_latest_tag_dockerhub() {
    local repo="$1"
    
    local api_url="https://hub.docker.com/v2/repositories/library/${repo}/tags?page_size=50"
    [[ "$repo" == *"/"* ]] && api_url="https://hub.docker.com/v2/repositories/${repo}/tags?page_size=50"
    
    local tags
    tags=$(curl -sSL "$api_url" 2>/dev/null | grep -oP '"name":"\K[^"]+')
    
    # Find first stable version (semver, not rc/alpha/beta)
    while read -r tag; do
        if [[ "$tag" =~ ^[0-9]+\.[0-9]+ ]] && [[ ! "$tag" =~ (rc|alpha|beta|dev|test|nightly) ]]; then
            echo "$tag"
            return
        fi
    done <<< "$tags"
    
    echo "latest"
}

# Search Quay.io
os_search_quay() {
    local query="$1"
    local limit="${2:-10}"
    
    os_log_section "📦 Quay.io"
    
    local url="https://quay.io/api/v1/find/repositories?query=${query}&page=1"
    local results
    results=$(curl -sSL "$url" 2>/dev/null)
    
    if [[ -z "$results" ]]; then
        os_log_warn "Could not fetch Quay.io results"
        return 1
    fi
    
    echo "$results" | grep -oP '"name":"\K[^"]+' | head -"$limit" | while read -r repo; do
        local namespace
        namespace=$(echo "$results" | grep -oB5 "\"name\":\"${repo}\"" | grep -oP '"namespace":"\K[^"]+' | head -1)
        printf "  %b%-30s%b quay.io/%s/%s\n" "$C_CYAN" "$repo" "$C_RESET" "${namespace:-library}" "$repo"
    done
}

# Search LinuxContainers.org
os_search_lxc_images() {
    local query="$1"
    
    os_log_section "📦 LXC Images"
    
    # Query available LXC images
    if command -v lxc &>/dev/null; then
        lxc image list images: "$query" -c lfpdsu --format table 2>/dev/null | head -15
    else
        # Fallback to API
        local url="https://images.linuxcontainers.org/streams/v1/images.json"
        local results
        results=$(curl -sSL "$url" 2>/dev/null | grep -oP '"alias":"\K[^"]+' | grep -i "$query" | head -10)
        
        while read -r image; do
            printf "  %b%s%b\n" "$C_CYAN" "$image" "$C_RESET"
        done <<< "$results"
    fi
}

# Search native package managers
os_search_packages() {
    local query="$1"
    
    os_log_section "📦 Native Packages (${OS_PKG_MANAGER})"
    
    case "$OS_PKG_MANAGER" in
        apt)    apt-cache search "$query" 2>/dev/null | head -10 ;;
        dnf)    dnf search "$query" 2>/dev/null | grep -v "^==" | head -10 ;;
        apk)    apk search "$query" 2>/dev/null | head -10 ;;
        pacman) pacman -Ss "$query" 2>/dev/null | head -20 ;;
        zypper) zypper search "$query" 2>/dev/null | tail -n +5 | head -10 ;;
    esac
}

# Unified search across all sources
os_unified_search() {
    local query="$1"
    
    os_log_header "Search Results: $query"
    
    # Run searches in parallel
    os_search_dockerhub "$query" &
    local pid_docker=$!
    
    os_search_quay "$query" &
    local pid_quay=$!
    
    os_search_lxc_images "$query" &
    local pid_lxc=$!
    
    os_search_packages "$query" &
    local pid_pkg=$!
    
    # Wait for all
    wait $pid_docker $pid_quay $pid_lxc $pid_pkg 2>/dev/null
    
    echo ""
    os_log_hr
    echo ""
    
    # Offer to install
    os_log_info "Enter the full image/package name to install, or press Enter to go back"
    read -r -p "$(printf '%b▶%b ' "$C_CYAN" "$C_RESET")" selection
    
    if [[ -n "$selection" ]]; then
        # Determine source and install
        if [[ "$selection" == *"/"* ]]; then
            # Docker/Quay image
            os_log_info "Select target for $selection"
            OS_TARGET=$(os_select_target)
            OS_APP="${selection##*/}"
            DOCKER_IMAGE="$selection"
            os_load_adapter "$OS_TARGET"
            adapter_install
        else
            # Native package
            os_log_info "Install $selection via ${OS_PKG_MANAGER}?"
            if os_confirm; then
                pkg_install "$selection"
            fi
        fi
    fi
}
