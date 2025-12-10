#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  OmniScript - Builder Stack Module                                         ║
# ║  Compose complete environments in one step                                 ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

[[ -n "${_OS_MODULE_BUILDER_LOADED:-}" ]] && return 0
readonly _OS_MODULE_BUILDER_LOADED=1

# Predefined stack templates
declare -A STACK_TEMPLATES=(
    [lamp]="apache mysql php phpmyadmin"
    [lemp]="nginx mysql php phpmyadmin"
    [mern]="mongodb express react nginx"
    [mean]="mongodb express angular nginx"
    [django]="postgres python nginx redis"
    [rails]="postgres ruby nginx redis"
    [wordpress]="wordpress mysql nginx"
    [nextcloud]="nextcloud postgres redis nginx"
)

# Available components
declare -A STACK_DATABASES=(
    [postgres]="PostgreSQL|postgres:16|5432"
    [mysql]="MySQL|mysql:8|3306"
    [mariadb]="MariaDB|mariadb:11|3306"
    [mongodb]="MongoDB|mongo:7|27017"
    [redis]="Redis|redis:7|6379"
)

declare -A STACK_BACKENDS=(
    [python]="Python/Flask|python:3.12-slim|5000"
    [node]="Node.js|node:20-slim|3000"
    [ruby]="Ruby/Rails|ruby:3.3-slim|3000"
    [go]="Go|golang:1.22-alpine|8080"
    [php]="PHP-FPM|php:8.3-fpm|9000"
)

declare -A STACK_FRONTENDS=(
    [react]="React|node:20-slim|3000"
    [vue]="Vue.js|node:20-slim|3000"
    [angular]="Angular|node:20-slim|4200"
    [svelte]="Svelte|node:20-slim|5173"
    [static]="Static HTML|nginx:alpine|80"
)

declare -A STACK_PROXIES=(
    [traefik]="Traefik|traefik:v3.0|80,443,8080"
    [nginx]="Nginx Proxy|nginx:alpine|80,443"
    [caddy]="Caddy|caddy:2|80,443"
    [haproxy]="HAProxy|haproxy:2.9|80,443"
)

# Build custom stack interactively
os_build_stack() {
    os_log_header "Builder Stack"
    
    local options=(
        "📋 Use Template"
        "🔧 Custom Stack"
        "🚪 Cancel"
    )
    
    local choice
    choice=$(os_select "Select option" "${options[@]}")
    
    case $choice in
        0) os_stack_from_template ;;
        1) os_stack_custom ;;
        2) return 0 ;;
    esac
}

# Build from predefined template
os_stack_from_template() {
    local template_names=()
    for name in "${!STACK_TEMPLATES[@]}"; do
        template_names+=("${name^^}: ${STACK_TEMPLATES[$name]}")
    done
    
    local choice
    choice=$(os_select "Select Template" "${template_names[@]}")
    
    local template_name
    template_name=$(echo "${template_names[$choice]}" | cut -d: -f1 | tr '[:upper:]' '[:lower:]')
    
    os_log_info "Building ${template_name} stack..."
    
    local components="${STACK_TEMPLATES[$template_name]}"
    os_generate_stack_compose "$template_name" "$components"
}

# Build custom stack
os_stack_custom() {
    local stack_name
    os_log_info "Enter stack name:"
    read -r -p "▶ " stack_name
    stack_name="${stack_name:-custom-stack}"
    
    local selected_components=()
    
    # Select database
    os_log_section "Select Database (optional)"
    local db_options=("(Skip)")
    for db in "${!STACK_DATABASES[@]}"; do
        local info="${STACK_DATABASES[$db]}"
        db_options+=("${info%%|*} ($db)")
    done
    
    local db_choice
    db_choice=$(os_select "Database" "${db_options[@]}")
    
    if [[ $db_choice -gt 0 ]]; then
        local db_name
        db_name=$(echo "${db_options[$db_choice]}" | grep -oP '\(\K[^)]+')
        selected_components+=("db:$db_name")
    fi
    
    # Select backend
    os_log_section "Select Backend (optional)"
    local be_options=("(Skip)")
    for be in "${!STACK_BACKENDS[@]}"; do
        local info="${STACK_BACKENDS[$be]}"
        be_options+=("${info%%|*} ($be)")
    done
    
    local be_choice
    be_choice=$(os_select "Backend" "${be_options[@]}")
    
    if [[ $be_choice -gt 0 ]]; then
        local be_name
        be_name=$(echo "${be_options[$be_choice]}" | grep -oP '\(\K[^)]+')
        selected_components+=("backend:$be_name")
    fi
    
    # Select frontend
    os_log_section "Select Frontend (optional)"
    local fe_options=("(Skip)")
    for fe in "${!STACK_FRONTENDS[@]}"; do
        local info="${STACK_FRONTENDS[$fe]}"
        fe_options+=("${info%%|*} ($fe)")
    done
    
    local fe_choice
    fe_choice=$(os_select "Frontend" "${fe_options[@]}")
    
    if [[ $fe_choice -gt 0 ]]; then
        local fe_name
        fe_name=$(echo "${fe_options[$fe_choice]}" | grep -oP '\(\K[^)]+')
        selected_components+=("frontend:$fe_name")
    fi
    
    # Select proxy
    os_log_section "Select Reverse Proxy (optional)"
    local px_options=("(Skip)")
    for px in "${!STACK_PROXIES[@]}"; do
        local info="${STACK_PROXIES[$px]}"
        px_options+=("${info%%|*} ($px)")
    done
    
    local px_choice
    px_choice=$(os_select "Proxy" "${px_options[@]}")
    
    if [[ $px_choice -gt 0 ]]; then
        local px_name
        px_name=$(echo "${px_options[$px_choice]}" | grep -oP '\(\K[^)]+')
        selected_components+=("proxy:$px_name")
    fi
    
    if [[ ${#selected_components[@]} -eq 0 ]]; then
        os_log_warn "No components selected"
        return 1
    fi
    
    os_generate_stack_compose "$stack_name" "${selected_components[*]}"
}

# Generate docker-compose for stack
os_generate_stack_compose() {
    local stack_name="$1"
    local components="$2"
    
    local stack_dir="${OS_CONFIG_DIR}/stacks/${stack_name}"
    os_ensure_dir "$stack_dir"
    
    local compose_file="${stack_dir}/docker-compose.yml"
    
    os_log_info "Generating $compose_file..."
    
    {
        echo "# OmniScript Stack: ${stack_name}"
        echo "# Generated: $(date -Iseconds)"
        echo ""
        echo "services:"
        
        for component in $components; do
            local type name
            if [[ "$component" == *":"* ]]; then
                type="${component%%:*}"
                name="${component#*:}"
            else
                name="$component"
                type="service"
            fi
            
            case "$type" in
                db)
                    local info="${STACK_DATABASES[$name]}"
                    IFS='|' read -r label image port <<< "$info"
                    os_generate_service "$name" "$image" "$port"
                    ;;
                backend)
                    local info="${STACK_BACKENDS[$name]}"
                    IFS='|' read -r label image port <<< "$info"
                    os_generate_service "$name" "$image" "$port"
                    ;;
                frontend)
                    local info="${STACK_FRONTENDS[$name]}"
                    IFS='|' read -r label image port <<< "$info"
                    os_generate_service "$name" "$image" "$port"
                    ;;
                proxy)
                    local info="${STACK_PROXIES[$name]}"
                    IFS='|' read -r label image ports <<< "$info"
                    os_generate_service "$name" "$image" "$ports"
                    ;;
            esac
        done
        
        echo ""
        echo "networks:"
        echo "  ${stack_name}-network:"
        echo "    driver: bridge"
        
        echo ""
        echo "volumes:"
        for component in $components; do
            local name="${component#*:}"
            echo "  ${name}-data:"
        done
        
    } > "$compose_file"
    
    os_log_success "Stack generated: $compose_file"
    
    # Ask about deployment
    local deploy_options=(
        "🚀 Deploy Now"
        "📄 View Compose File"
        "✏️  Edit Manually"
        "🚪 Exit"
    )
    
    local deploy_choice
    deploy_choice=$(os_select "What's next?" "${deploy_options[@]}")
    
    case $deploy_choice in
        0)
            os_log_info "Deploying stack..."
            docker compose -f "$compose_file" up -d
            os_log_success "Stack deployed!"
            ;;
        1)
            cat "$compose_file"
            ;;
        2)
            ${EDITOR:-nano} "$compose_file"
            ;;
    esac
}

# Generate a single service block
os_generate_service() {
    local name="$1"
    local image="$2"
    local ports="$3"
    
    echo ""
    echo "  ${name}:"
    echo "    image: ${image}"
    echo "    container_name: \${COMPOSE_PROJECT_NAME:-stack}-${name}"
    echo "    restart: unless-stopped"
    
    if [[ -n "$ports" ]]; then
        echo "    ports:"
        IFS=',' read -ra port_list <<< "$ports"
        for port in "${port_list[@]}"; do
            echo "      - \"${port}:${port}\""
        done
    fi
    
    echo "    volumes:"
    echo "      - ${name}-data:/data"
    echo "    networks:"
    echo "      - \${COMPOSE_PROJECT_NAME:-stack}-network"
}
