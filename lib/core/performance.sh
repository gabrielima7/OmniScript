#!/usr/bin/env bash
#===============================================================================
# OmniScript - Performance Helper
# Optimize script loading and caching
#===============================================================================
# shellcheck disable=SC2034

#-------------------------------------------------------------------------------
# Lazy Loading Configuration
#-------------------------------------------------------------------------------
OS_LAZY_LOAD="${OS_LAZY_LOAD:-true}"

# Libraries loaded on demand
declare -gA OS_LAZY_LIBS=(
    [search]="lib/features/search.sh"
    [autotag]="lib/features/autotag.sh"
    [security]="lib/features/security.sh"
    [backup]="lib/features/backup.sh"
    [update]="lib/features/update.sh"
    [builder]="lib/menus/builder.sh"
)

#-------------------------------------------------------------------------------
# Lazy Load Functions
#-------------------------------------------------------------------------------
os_lazy_load() {
    local lib="$1"
    
    if [[ -v "OS_LAZY_LIBS[$lib]" ]]; then
        local lib_path="${OS_SCRIPT_DIR}/${OS_LAZY_LIBS[$lib]}"
        
        if [[ -f "$lib_path" ]]; then
            # shellcheck source=/dev/null
            source "$lib_path"
            os_debug "Lazy loaded: ${lib}"
            return 0
        fi
    fi
    
    return 1
}

#-------------------------------------------------------------------------------
# Compiled Cache (for faster startup)
#-------------------------------------------------------------------------------
OS_CACHE_DIR="${OS_DATA_DIR}/cache"
OS_COMPILED_CACHE="${OS_CACHE_DIR}/compiled.sh"
OS_CACHE_VERSION_FILE="${OS_CACHE_DIR}/version"

os_compile_libs() {
    local output="$1"
    
    mkdir -p "$(dirname "$output")"
    
    {
        echo "#!/usr/bin/env bash"
        echo "# OmniScript Compiled Libraries - Generated $(date -Iseconds)"
        echo "# Version: ${OS_VERSION}"
        echo ""
        
        # Core libraries (always needed)
        for lib in ui utils distro targets; do
            local lib_path="${OS_LIB_DIR}/core/${lib}.sh"
            if [[ -f "$lib_path" ]]; then
                echo "# === ${lib}.sh ==="
                grep -v '^#!/' "$lib_path" | grep -v '^#.*shellcheck'
                echo ""
            fi
        done
        
    } > "$output"
    
    # Store version
    echo "$OS_VERSION" > "${OS_CACHE_VERSION_FILE}"
    
    os_debug "Compiled libraries to: ${output}"
}

os_load_compiled() {
    if [[ ! -f "$OS_COMPILED_CACHE" ]]; then
        return 1
    fi
    
    # Check version match
    if [[ -f "${OS_CACHE_VERSION_FILE}" ]]; then
        local cached_version
        cached_version=$(cat "${OS_CACHE_VERSION_FILE}")
        
        if [[ "$cached_version" != "$OS_VERSION" ]]; then
            rm -f "$OS_COMPILED_CACHE"
            return 1
        fi
    fi
    
    # shellcheck source=/dev/null
    source "$OS_COMPILED_CACHE"
    return 0
}

#-------------------------------------------------------------------------------
# Startup Optimization
#-------------------------------------------------------------------------------
os_fast_init() {
    # Try compiled cache first
    if [[ "${OS_LAZY_LOAD}" == "true" ]] && os_load_compiled; then
        os_debug "Loaded from compiled cache"
        return
    fi
    
    # Load core libraries normally
    for lib in ui utils distro targets; do
        local lib_path="${OS_LIB_DIR}/core/${lib}.sh"
        if [[ -f "$lib_path" ]]; then
            # shellcheck source=/dev/null
            source "$lib_path"
        fi
    done
    
    # Generate compiled cache for next time
    if [[ "${OS_LAZY_LOAD}" == "true" ]]; then
        os_compile_libs "$OS_COMPILED_CACHE" &
    fi
}

#-------------------------------------------------------------------------------
# Memory Optimization
#-------------------------------------------------------------------------------
os_cleanup_memory() {
    # Clear large arrays after use
    unset OS_SEARCH_RESULTS 2>/dev/null || true
    unset OS_BACKUP_LIST 2>/dev/null || true
    
    # Clear function-local caches
    if declare -F os_search_clear_cache &>/dev/null; then
        os_search_clear_cache
    fi
}

#-------------------------------------------------------------------------------
# Benchmark Functions
#-------------------------------------------------------------------------------
os_benchmark() {
    local name="$1"
    shift
    local cmd="$*"
    
    local start end duration
    start=$(date +%s%N)
    
    eval "$cmd"
    
    end=$(date +%s%N)
    duration=$(( (end - start) / 1000000 ))
    
    echo "${name}: ${duration}ms"
}

os_profile_startup() {
    echo "OmniScript Startup Profile"
    echo "=========================="
    
    os_benchmark "Core UI" "source ${OS_LIB_DIR}/core/ui.sh"
    os_benchmark "Core Utils" "source ${OS_LIB_DIR}/core/utils.sh"
    os_benchmark "Core Distro" "source ${OS_LIB_DIR}/core/distro.sh"
    os_benchmark "Core Targets" "source ${OS_LIB_DIR}/core/targets.sh"
    
    echo ""
    echo "Feature Libraries (lazy loaded):"
    
    for lib in search autotag security backup update; do
        os_benchmark "Feature $lib" "source ${OS_LIB_DIR}/features/${lib}.sh"
    done
}

#-------------------------------------------------------------------------------
# Initialization Flag
#-------------------------------------------------------------------------------
OS_PERFORMANCE_LOADED=true
