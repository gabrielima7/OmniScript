#!/usr/bin/env bash
#===============================================================================
# OmniScript - Smart Search Library
# Unified search across Docker Hub, Quay.io, and native package managers
#===============================================================================
# shellcheck disable=SC2034

#-------------------------------------------------------------------------------
# Search Configuration
#-------------------------------------------------------------------------------
OS_SEARCH_CACHE_DIR="${OS_DATA_DIR}/cache/search"
OS_SEARCH_CACHE_TTL=3600  # 1 hour

#-------------------------------------------------------------------------------
# Unified Search
#-------------------------------------------------------------------------------
os_search() {
    local term="${1:-}"
    
    if [[ -z "$term" ]]; then
        term=$(os_prompt "Search for")
        [[ -z "$term" ]] && return 1
    fi
    
    os_menu_header "Search Results: ${term}"
    
    local found=false
    
    # Search based on current target
    case "${OS_CURRENT_TARGET}" in
        docker|podman)
            os_search_docker_hub "$term" && found=true
            os_search_quay "$term" && found=true
            ;;
        baremetal)
            os_search_packages "$term" && found=true
            ;;
        lxc)
            os_search_lxc_images "$term" && found=true
            ;;
    esac
    
    # Always search local modules
    os_search_modules "$term" && found=true
    
    if [[ "$found" == "false" ]]; then
        os_warn "No results found for: ${term}"
    fi
}

#-------------------------------------------------------------------------------
# Docker Hub Search
#-------------------------------------------------------------------------------
os_search_docker_hub() {
    local term="$1"
    local limit="${2:-10}"
    
    os_require_command curl || return 1
    
    echo ""
    echo -e "  ${C_BOLD}${EMOJI_DOCKER} Docker Hub:${C_RESET}"
    
    local cache_file="${OS_SEARCH_CACHE_DIR}/dockerhub_${term}.json"
    mkdir -p "${OS_SEARCH_CACHE_DIR}"
    
    local result
    
    # Check cache
    if [[ -f "$cache_file" ]] && _os_cache_valid "$cache_file"; then
        result=$(cat "$cache_file")
    else
        result=$(curl -fsSL "https://hub.docker.com/v2/search/repositories/?query=${term}&page_size=${limit}" 2>/dev/null)
        echo "$result" > "$cache_file" 2>/dev/null || true
    fi
    
    if [[ -z "$result" ]]; then
        echo -e "    ${C_DIM}Failed to fetch results${C_RESET}"
        return 1
    fi
    
    # Parse results
    if command -v jq &> /dev/null; then
        echo "$result" | jq -r '.results[]? | "    \(.repo_name) ★\(.star_count) - \(.short_description // "No description")[0:60]"' 2>/dev/null | head -10
    else
        # Basic parsing without jq
        echo "$result" | grep -oP '"repo_name"\s*:\s*"\K[^"]+' | while read -r name; do
            echo "    ${name}"
        done | head -10
    fi
    
    return 0
}

#-------------------------------------------------------------------------------
# Quay.io Search
#-------------------------------------------------------------------------------
os_search_quay() {
    local term="$1"
    local limit="${2:-10}"
    
    os_require_command curl || return 1
    
    echo ""
    echo -e "  ${C_BOLD}🔴 Quay.io:${C_RESET}"
    
    local result
    result=$(curl -fsSL "https://quay.io/api/v1/find/repositories?query=${term}&page=1" 2>/dev/null)
    
    if [[ -z "$result" ]]; then
        echo -e "    ${C_DIM}Failed to fetch results${C_RESET}"
        return 1
    fi
    
    if command -v jq &> /dev/null; then
        echo "$result" | jq -r '.results[]? | "    quay.io/\(.namespace.name)/\(.name) - \(.description // "No description")[0:50]"' 2>/dev/null | head -$limit
    else
        echo "$result" | grep -oP '"name"\s*:\s*"\K[^"]+' | head -$limit | while read -r name; do
            echo "    quay.io/${name}"
        done
    fi
    
    return 0
}

#-------------------------------------------------------------------------------
# Native Package Search
#-------------------------------------------------------------------------------
os_search_packages() {
    local term="$1"
    
    echo ""
    echo -e "  ${C_BOLD}${EMOJI_PACKAGE} Native Packages (${OS_PKG_MANAGER}):${C_RESET}"
    
    case "${OS_PKG_MANAGER}" in
        apt)
            apt-cache search "$term" 2>/dev/null | head -10 | while read -r line; do
                echo "    ${line}"
            done
            ;;
        dnf|yum)
            dnf search "$term" 2>/dev/null | grep -v "^=" | head -10 | while read -r line; do
                echo "    ${line}"
            done
            ;;
        pacman)
            pacman -Ss "$term" 2>/dev/null | head -10 | while read -r line; do
                echo "    ${line}"
            done
            ;;
        zypper)
            zypper search "$term" 2>/dev/null | tail -n +5 | head -10 | while read -r line; do
                echo "    ${line}"
            done
            ;;
        apk)
            apk search "$term" 2>/dev/null | head -10 | while read -r line; do
                echo "    ${line}"
            done
            ;;
        *)
            echo -e "    ${C_DIM}Package search not supported for ${OS_PKG_MANAGER}${C_RESET}"
            return 1
            ;;
    esac
    
    return 0
}

#-------------------------------------------------------------------------------
# LXC Image Search
#-------------------------------------------------------------------------------
os_search_lxc_images() {
    local term="$1"
    
    if ! command -v lxc &> /dev/null; then
        return 1
    fi
    
    echo ""
    echo -e "  ${C_BOLD}${EMOJI_LXC} LXC Images:${C_RESET}"
    
    lxc image list images: "$term" --format table 2>/dev/null | head -15 || {
        echo -e "    ${C_DIM}Failed to fetch images${C_RESET}"
        return 1
    }
    
    return 0
}

#-------------------------------------------------------------------------------
# Local Module Search
#-------------------------------------------------------------------------------
os_search_modules() {
    local term="$1"
    
    echo ""
    echo -e "  ${C_BOLD}${EMOJI_GEAR} OmniScript Modules:${C_RESET}"
    
    local found=false
    
    for module_file in "${OS_MODULES_DIR}"/*/*.sh; do
        if [[ -f "$module_file" ]]; then
            local name
            name=$(basename "$module_file" .sh)
            
            if [[ "${name,,}" == *"${term,,}"* ]]; then
                # shellcheck source=/dev/null
                source "$module_file"
                
                local desc="${OS_MODULE_DESCRIPTION:-No description}"
                local version="${OS_MODULE_VERSION:-}"
                
                echo -e "    ${C_CYAN}${name}${C_RESET} ${C_DIM}${version}${C_RESET} - ${desc}"
                found=true
            fi
        fi
    done
    
    if [[ "$found" == "false" ]]; then
        echo -e "    ${C_DIM}No matching modules found${C_RESET}"
        return 1
    fi
    
    return 0
}

#-------------------------------------------------------------------------------
# Cache Helpers
#-------------------------------------------------------------------------------
_os_cache_valid() {
    local file="$1"
    local ttl="${2:-$OS_SEARCH_CACHE_TTL}"
    
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    
    local file_age
    file_age=$(( $(date +%s) - $(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null) ))
    
    [[ $file_age -lt $ttl ]]
}

os_search_clear_cache() {
    rm -rf "${OS_SEARCH_CACHE_DIR}"
    mkdir -p "${OS_SEARCH_CACHE_DIR}"
    os_success "Search cache cleared"
}

#-------------------------------------------------------------------------------
# Interactive Search
#-------------------------------------------------------------------------------
os_search_interactive() {
    while true; do
        os_clear_screen
        os_banner_small
        
        local term
        term=$(os_prompt "Search (q to quit)")
        
        [[ "$term" == "q" ]] || [[ -z "$term" ]] && break
        
        os_search "$term"
        
        echo ""
        read -rp "Press Enter to continue..."
    done
}

#-------------------------------------------------------------------------------
# Initialization Flag
#-------------------------------------------------------------------------------
OS_SEARCH_LOADED=true
