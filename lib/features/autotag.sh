#!/usr/bin/env bash
#===============================================================================
# OmniScript - Auto-tagging Library
# Automatically find latest stable versions (avoiding latest/edge tags)
#===============================================================================
# shellcheck disable=SC2034

#-------------------------------------------------------------------------------
# Auto-tag Configuration
#-------------------------------------------------------------------------------
OS_AUTOTAG_CACHE_DIR="${OS_DATA_DIR}/cache/tags"
OS_AUTOTAG_CACHE_TTL=3600  # 1 hour

# Tags to exclude (never use these)
OS_AUTOTAG_EXCLUDE=(
    "latest"
    "edge"
    "nightly"
    "dev"
    "develop"
    "development"
    "master"
    "main"
    "unstable"
    "beta"
    "alpha"
    "rc"
    "test"
    "testing"
)

#-------------------------------------------------------------------------------
# Get Best Tag
#-------------------------------------------------------------------------------
os_get_best_tag() {
    local image="$1"
    local fallback="${2:-latest}"
    
    os_debug "Finding best tag for: ${image}"
    
    local tag
    
    # Try Docker Hub first
    if [[ "$image" != *"/"* ]] || [[ "$image" == "library/"* ]]; then
        tag=$(os_get_dockerhub_best_tag "$image")
    elif [[ "$image" == quay.io/* ]]; then
        tag=$(os_get_quay_best_tag "$image")
    elif [[ "$image" == ghcr.io/* ]]; then
        tag=$(os_get_ghcr_best_tag "$image")
    else
        # Generic Docker Hub image
        tag=$(os_get_dockerhub_best_tag "$image")
    fi
    
    echo "${tag:-$fallback}"
}

#-------------------------------------------------------------------------------
# Docker Hub Tags
#-------------------------------------------------------------------------------
os_get_dockerhub_best_tag() {
    local image="$1"
    
    # Normalize image name
    if [[ "$image" != *"/"* ]]; then
        image="library/${image}"
    fi
    
    local cache_key
    cache_key=$(echo "$image" | tr '/' '_')
    local cache_file="${OS_AUTOTAG_CACHE_DIR}/${cache_key}.json"
    
    mkdir -p "${OS_AUTOTAG_CACHE_DIR}"
    
    local result
    
    # Check cache
    if [[ -f "$cache_file" ]] && _os_autotag_cache_valid "$cache_file"; then
        result=$(cat "$cache_file")
    else
        result=$(curl -fsSL "https://hub.docker.com/v2/repositories/${image}/tags?page_size=100" 2>/dev/null)
        
        if [[ -n "$result" ]]; then
            echo "$result" > "$cache_file" 2>/dev/null || true
        fi
    fi
    
    if [[ -z "$result" ]]; then
        return 1
    fi
    
    # Extract and process tags
    local tags
    if command -v jq &> /dev/null; then
        tags=$(echo "$result" | jq -r '.results[].name' 2>/dev/null)
    else
        tags=$(echo "$result" | grep -oP '"name"\s*:\s*"\K[^"]+')
    fi
    
    # Find best semver tag
    local best_tag
    best_tag=$(_os_select_best_tag "$tags")
    
    echo "$best_tag"
}

#-------------------------------------------------------------------------------
# Quay.io Tags
#-------------------------------------------------------------------------------
os_get_quay_best_tag() {
    local image="$1"
    
    # Remove quay.io/ prefix
    image="${image#quay.io/}"
    
    local result
    result=$(curl -fsSL "https://quay.io/api/v1/repository/${image}/tag/?limit=100" 2>/dev/null)
    
    if [[ -z "$result" ]]; then
        return 1
    fi
    
    local tags
    if command -v jq &> /dev/null; then
        tags=$(echo "$result" | jq -r '.tags[].name' 2>/dev/null)
    else
        tags=$(echo "$result" | grep -oP '"name"\s*:\s*"\K[^"]+')
    fi
    
    _os_select_best_tag "$tags"
}

#-------------------------------------------------------------------------------
# GitHub Container Registry Tags
#-------------------------------------------------------------------------------
os_get_ghcr_best_tag() {
    local image="$1"
    
    # Remove ghcr.io/ prefix
    image="${image#ghcr.io/}"
    
    # GHCR requires authentication for most repos, use fallback
    os_debug "GHCR: Authentication required, using latest"
    echo "latest"
}

#-------------------------------------------------------------------------------
# Tag Selection Logic
#-------------------------------------------------------------------------------
_os_select_best_tag() {
    local tags="$1"
    
    local valid_tags=()
    
    # Filter and collect valid semantic version tags
    while IFS= read -r tag; do
        [[ -z "$tag" ]] && continue
        
        # Skip excluded tags
        local skip=false
        for exclude in "${OS_AUTOTAG_EXCLUDE[@]}"; do
            if [[ "${tag,,}" == "$exclude" ]] || [[ "${tag,,}" == *"$exclude"* ]]; then
                skip=true
                break
            fi
        done
        
        [[ "$skip" == "true" ]] && continue
        
        # Check if it looks like a semver
        if _os_is_semver "$tag"; then
            valid_tags+=("$tag")
        fi
    done <<< "$tags"
    
    if [[ ${#valid_tags[@]} -eq 0 ]]; then
        return 1
    fi
    
    # Sort by version and get the highest
    printf '%s\n' "${valid_tags[@]}" | sort -rV | head -1
}

_os_is_semver() {
    local tag="$1"
    
    # Remove common prefixes
    tag="${tag#v}"
    
    # Match common version patterns
    # X.Y.Z, X.Y, X.Y.Z-suffix, etc.
    [[ "$tag" =~ ^[0-9]+(\.[0-9]+)?(\.[0-9]+)?(-[a-zA-Z0-9]+)?$ ]]
}

#-------------------------------------------------------------------------------
# Cache Helpers
#-------------------------------------------------------------------------------
_os_autotag_cache_valid() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    
    local file_age
    file_age=$(( $(date +%s) - $(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null) ))
    
    [[ $file_age -lt $OS_AUTOTAG_CACHE_TTL ]]
}

os_autotag_clear_cache() {
    rm -rf "${OS_AUTOTAG_CACHE_DIR}"
    mkdir -p "${OS_AUTOTAG_CACHE_DIR}"
    os_success "Tag cache cleared"
}

#-------------------------------------------------------------------------------
# Image with Best Tag
#-------------------------------------------------------------------------------
os_image_with_tag() {
    local image="$1"
    local fallback="${2:-latest}"
    
    # If image already has a tag, return as-is
    if [[ "$image" == *":"* ]]; then
        echo "$image"
        return
    fi
    
    local tag
    tag=$(os_get_best_tag "$image" "$fallback")
    
    echo "${image}:${tag}"
}

#-------------------------------------------------------------------------------
# Check for Updates
#-------------------------------------------------------------------------------
os_check_image_update() {
    local current_image="$1"
    
    local image_name="${current_image%%:*}"
    local current_tag="${current_image##*:}"
    
    if [[ "$current_tag" == "$current_image" ]]; then
        current_tag="latest"
    fi
    
    local best_tag
    best_tag=$(os_get_best_tag "$image_name")
    
    if [[ -z "$best_tag" ]]; then
        echo "unknown"
        return 1
    fi
    
    if [[ "$current_tag" == "latest" ]]; then
        echo "current:latest recommended:${best_tag}"
        return 0
    fi
    
    if os_version_compare "$best_tag" "gt" "$current_tag"; then
        echo "update_available:${best_tag}"
        return 0
    fi
    
    echo "up_to_date"
}

#-------------------------------------------------------------------------------
# Interactive Tag Selection
#-------------------------------------------------------------------------------
os_select_tag() {
    local image="$1"
    
    os_info "Fetching available tags for ${image}..."
    
    local tags
    
    if [[ "$image" != *"/"* ]] || [[ "$image" == "library/"* ]]; then
        if [[ "$image" != *"/"* ]]; then
            image="library/${image}"
        fi
        tags=$(curl -fsSL "https://hub.docker.com/v2/repositories/${image}/tags?page_size=25" 2>/dev/null | jq -r '.results[].name' 2>/dev/null)
    fi
    
    if [[ -z "$tags" ]]; then
        os_error "Could not fetch tags for ${image}"
        return 1
    fi
    
    local tag_array=()
    while IFS= read -r tag; do
        [[ -n "$tag" ]] && tag_array+=("$tag")
    done <<< "$tags"
    
    os_select "Select tag" "${tag_array[@]}"
    
    if [[ $? -eq 0 ]]; then
        echo "$OS_SELECTED_VALUE"
        return 0
    fi
    
    return 1
}

#-------------------------------------------------------------------------------
# Initialization Flag
#-------------------------------------------------------------------------------
OS_AUTOTAG_LOADED=true
