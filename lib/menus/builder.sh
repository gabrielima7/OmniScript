#!/usr/bin/env bash
#===============================================================================
# OmniScript - Builder Stack Library
# Compose complete environments from templates and components
#===============================================================================
# shellcheck disable=SC2034

#-------------------------------------------------------------------------------
# Stack Templates
#-------------------------------------------------------------------------------
declare -A OS_STACK_TEMPLATES=(
    [lemp]="Linux + Nginx + MySQL + PHP"
    [mean]="MongoDB + Express + Angular + Node"
    [mern]="MongoDB + Express + React + Node"
    [lamp]="Linux + Apache + MySQL + PHP"
    [wordpress]="WordPress with MySQL and Nginx"
    [gitops]="GitLab + GitLab Runner + Registry"
    [monitoring]="Prometheus + Grafana + AlertManager"
    [logging]="Loki + Promtail + Grafana"
    [media]="Jellyfin + Sonarr + Radarr + Prowlarr"
)

#-------------------------------------------------------------------------------
# Builder Menu
#-------------------------------------------------------------------------------
os_builder_menu() {
    while true; do
        os_clear_screen
        os_banner_small
        
        os_menu_header "${EMOJI_BUILDER} Builder Stack"
        
        echo -e "  ${C_DIM}Compose complete environments with pre-configured templates${C_RESET}"
        echo ""
        
        os_select "Choose option" \
            "Use Template" \
            "Custom Stack" \
            "Manage Stacks" \
            "Back"
        
        case $OS_SELECTED_INDEX in
            0) os_builder_templates ;;
            1) os_builder_custom ;;
            2) os_builder_manage ;;
            3|255) return ;;
        esac
    done
}

#-------------------------------------------------------------------------------
# Template Selection
#-------------------------------------------------------------------------------
os_builder_templates() {
    local templates=()
    local descriptions=()
    
    for key in "${!OS_STACK_TEMPLATES[@]}"; do
        templates+=("$key")
        descriptions+=("${key^^} - ${OS_STACK_TEMPLATES[$key]}")
    done
    descriptions+=("Back")
    
    os_clear_screen
    os_banner_small
    
    os_menu_header "Stack Templates"
    
    os_select "Select template" "${descriptions[@]}"
    
    local last_index=$((${#descriptions[@]} - 1))
    
    if [[ $OS_SELECTED_INDEX -eq $last_index ]] || [[ $OS_SELECTED_INDEX -eq 255 ]]; then
        return
    fi
    
    local template="${templates[$OS_SELECTED_INDEX]}"
    
    os_build_stack "$template"
}

#-------------------------------------------------------------------------------
# Stack Building
#-------------------------------------------------------------------------------
os_build_stack() {
    local template="$1"
    
    os_clear_screen
    os_banner_small
    
    os_menu_header "Building: ${template^^}"
    
    echo -e "  ${C_DIM}${OS_STACK_TEMPLATES[$template]}${C_RESET}"
    echo ""
    
    # Get stack configuration
    local stack_name
    stack_name=$(os_prompt "Stack name" "$template")
    
    local domain
    domain=$(os_prompt "Domain (optional)" "")
    
    local email
    email=$(os_prompt "Email for SSL (optional)" "")
    
    # Generate passwords
    local db_password
    db_password=$(os_generate_password 24)
    local admin_password
    admin_password=$(os_generate_password 16)
    
    os_secret_set "${stack_name}_db_password" "$db_password"
    os_secret_set "${stack_name}_admin_password" "$admin_password"
    
    os_info "Generating stack configuration..."
    
    # Create stack directory
    local stack_dir="${OS_DATA_DIR}/${OS_CURRENT_TARGET}/stacks/${stack_name}"
    mkdir -p "$stack_dir"
    
    # Generate compose file based on template
    case "$template" in
        lemp)     _os_generate_lemp_stack "$stack_dir" "$stack_name" "$domain" ;;
        mean)     _os_generate_mean_stack "$stack_dir" "$stack_name" "$domain" ;;
        mern)     _os_generate_mern_stack "$stack_dir" "$stack_name" "$domain" ;;
        lamp)     _os_generate_lamp_stack "$stack_dir" "$stack_name" "$domain" ;;
        wordpress) _os_generate_wordpress_stack "$stack_dir" "$stack_name" "$domain" ;;
        gitops)   _os_generate_gitops_stack "$stack_dir" "$stack_name" "$domain" ;;
        monitoring) _os_generate_monitoring_stack "$stack_dir" "$stack_name" "$domain" ;;
        logging)  _os_generate_logging_stack "$stack_dir" "$stack_name" "$domain" ;;
        media)    _os_generate_media_stack "$stack_dir" "$stack_name" ;;
        *)        os_error "Unknown template: ${template}"; return 1 ;;
    esac
    
    os_success "Stack configuration generated"
    
    # Show summary
    echo ""
    echo -e "  ${C_BOLD}Stack Summary:${C_RESET}"
    echo -e "    Name: ${stack_name}"
    echo -e "    Location: ${stack_dir}"
    [[ -n "$domain" ]] && echo -e "    Domain: ${domain}"
    echo ""
    
    if os_confirm "Deploy this stack now?" "y"; then
        os_target_deploy "$stack_name"
        
        echo ""
        echo -e "  ${C_BOLD}Credentials:${C_RESET}"
        echo -e "    Database Password: ${C_DIM}${db_password}${C_RESET}"
        echo -e "    Admin Password: ${C_DIM}${admin_password}${C_RESET}"
        echo ""
        os_info "Credentials saved to secrets store"
    fi
    
    echo ""
    read -rp "Press Enter to continue..."
}

#-------------------------------------------------------------------------------
# Stack Templates Generation
#-------------------------------------------------------------------------------
_os_generate_lemp_stack() {
    local dir="$1"
    local name="$2"
    local domain="$3"
    
    local db_pass
    db_pass=$(os_secret_get "${name}_db_password")
    
    cat > "${dir}/docker-compose.yml" << EOF
version: "3.8"

services:
  nginx:
    image: nginx:alpine
    container_name: ${name}-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./www:/var/www/html
      - ./nginx/conf.d:/etc/nginx/conf.d
    depends_on:
      - php
    networks:
      - ${name}-network

  php:
    image: php:8.2-fpm-alpine
    container_name: ${name}-php
    restart: unless-stopped
    volumes:
      - ./www:/var/www/html
    networks:
      - ${name}-network

  mysql:
    image: mysql:8.0
    container_name: ${name}-mysql
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${db_pass}
      MYSQL_DATABASE: ${name}
    volumes:
      - mysql-data:/var/lib/mysql
    networks:
      - ${name}-network

networks:
  ${name}-network:
    driver: bridge

volumes:
  mysql-data:
EOF

    # Create default nginx config
    mkdir -p "${dir}/nginx/conf.d"
    cat > "${dir}/nginx/conf.d/default.conf" << 'EOF'
server {
    listen 80;
    server_name _;
    root /var/www/html;
    index index.php index.html;

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        fastcgi_pass php:9000;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF

    # Create default index
    mkdir -p "${dir}/www"
    cat > "${dir}/www/index.php" << 'EOF'
<?php
phpinfo();
EOF
}

_os_generate_wordpress_stack() {
    local dir="$1"
    local name="$2"
    local domain="${3:-localhost}"
    
    local db_pass
    db_pass=$(os_secret_get "${name}_db_password")
    
    cat > "${dir}/docker-compose.yml" << EOF
version: "3.8"

services:
  wordpress:
    image: wordpress:latest
    container_name: ${name}-wordpress
    restart: unless-stopped
    ports:
      - "8080:80"
    environment:
      WORDPRESS_DB_HOST: mysql
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: ${db_pass}
      WORDPRESS_DB_NAME: wordpress
    volumes:
      - wordpress-data:/var/www/html
    depends_on:
      - mysql
    networks:
      - ${name}-network

  mysql:
    image: mysql:8.0
    container_name: ${name}-mysql
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${db_pass}
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wordpress
      MYSQL_PASSWORD: ${db_pass}
    volumes:
      - mysql-data:/var/lib/mysql
    networks:
      - ${name}-network

networks:
  ${name}-network:
    driver: bridge

volumes:
  wordpress-data:
  mysql-data:
EOF
}

_os_generate_monitoring_stack() {
    local dir="$1"
    local name="$2"
    local domain="$3"
    
    cat > "${dir}/docker-compose.yml" << EOF
version: "3.8"

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: ${name}-prometheus
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus:/etc/prometheus
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
    networks:
      - ${name}-network

  grafana:
    image: grafana/grafana:latest
    container_name: ${name}-grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      GF_SECURITY_ADMIN_USER: admin
      GF_SECURITY_ADMIN_PASSWORD: admin
    volumes:
      - grafana-data:/var/lib/grafana
    depends_on:
      - prometheus
    networks:
      - ${name}-network

  alertmanager:
    image: prom/alertmanager:latest
    container_name: ${name}-alertmanager
    restart: unless-stopped
    ports:
      - "9093:9093"
    volumes:
      - ./alertmanager:/etc/alertmanager
    networks:
      - ${name}-network

  node-exporter:
    image: prom/node-exporter:latest
    container_name: ${name}-node-exporter
    restart: unless-stopped
    ports:
      - "9100:9100"
    networks:
      - ${name}-network

networks:
  ${name}-network:
    driver: bridge

volumes:
  prometheus-data:
  grafana-data:
EOF

    # Create prometheus config
    mkdir -p "${dir}/prometheus"
    cat > "${dir}/prometheus/prometheus.yml" << EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
EOF
}

_os_generate_mean_stack() {
    local dir="$1"
    local name="$2"
    local domain="$3"
    
    cat > "${dir}/docker-compose.yml" << EOF
version: "3.8"

services:
  mongodb:
    image: mongo:6
    container_name: ${name}-mongodb
    restart: unless-stopped
    volumes:
      - mongo-data:/data/db
    networks:
      - ${name}-network

  backend:
    image: node:18-alpine
    container_name: ${name}-backend
    restart: unless-stopped
    working_dir: /app
    volumes:
      - ./backend:/app
    command: sh -c "npm install && npm start"
    ports:
      - "3000:3000"
    environment:
      MONGODB_URI: mongodb://mongodb:27017/${name}
    depends_on:
      - mongodb
    networks:
      - ${name}-network

networks:
  ${name}-network:
    driver: bridge

volumes:
  mongo-data:
EOF
}

_os_generate_mern_stack() {
    _os_generate_mean_stack "$@"
}

_os_generate_lamp_stack() {
    local dir="$1"
    local name="$2"
    local domain="$3"
    
    local db_pass
    db_pass=$(os_secret_get "${name}_db_password")
    
    cat > "${dir}/docker-compose.yml" << EOF
version: "3.8"

services:
  apache:
    image: php:8.2-apache
    container_name: ${name}-apache
    restart: unless-stopped
    ports:
      - "80:80"
    volumes:
      - ./www:/var/www/html
    networks:
      - ${name}-network

  mysql:
    image: mysql:8.0
    container_name: ${name}-mysql
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${db_pass}
      MYSQL_DATABASE: ${name}
    volumes:
      - mysql-data:/var/lib/mysql
    networks:
      - ${name}-network

networks:
  ${name}-network:
    driver: bridge

volumes:
  mysql-data:
EOF
}

_os_generate_gitops_stack() {
    local dir="$1"
    local name="$2"
    local domain="$3"
    
    cat > "${dir}/docker-compose.yml" << EOF
version: "3.8"

services:
  gitlab:
    image: gitlab/gitlab-ce:latest
    container_name: ${name}-gitlab
    restart: unless-stopped
    hostname: ${domain:-gitlab.local}
    ports:
      - "80:80"
      - "443:443"
      - "22:22"
    volumes:
      - gitlab-config:/etc/gitlab
      - gitlab-logs:/var/log/gitlab
      - gitlab-data:/var/opt/gitlab
    networks:
      - ${name}-network

networks:
  ${name}-network:
    driver: bridge

volumes:
  gitlab-config:
  gitlab-logs:
  gitlab-data:
EOF
}

_os_generate_logging_stack() {
    local dir="$1"
    local name="$2"
    local domain="$3"
    
    cat > "${dir}/docker-compose.yml" << EOF
version: "3.8"

services:
  loki:
    image: grafana/loki:latest
    container_name: ${name}-loki
    restart: unless-stopped
    ports:
      - "3100:3100"
    volumes:
      - loki-data:/loki
    networks:
      - ${name}-network

  promtail:
    image: grafana/promtail:latest
    container_name: ${name}-promtail
    restart: unless-stopped
    volumes:
      - /var/log:/var/log:ro
      - ./promtail:/etc/promtail
    depends_on:
      - loki
    networks:
      - ${name}-network

  grafana:
    image: grafana/grafana:latest
    container_name: ${name}-grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    volumes:
      - grafana-data:/var/lib/grafana
    depends_on:
      - loki
    networks:
      - ${name}-network

networks:
  ${name}-network:
    driver: bridge

volumes:
  loki-data:
  grafana-data:
EOF
}

_os_generate_media_stack() {
    local dir="$1"
    local name="$2"
    
    cat > "${dir}/docker-compose.yml" << EOF
version: "3.8"

services:
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: ${name}-jellyfin
    restart: unless-stopped
    ports:
      - "8096:8096"
    volumes:
      - jellyfin-config:/config
      - ./media:/media
    networks:
      - ${name}-network

  sonarr:
    image: linuxserver/sonarr:latest
    container_name: ${name}-sonarr
    restart: unless-stopped
    ports:
      - "8989:8989"
    volumes:
      - sonarr-config:/config
      - ./media/tv:/tv
      - ./downloads:/downloads
    networks:
      - ${name}-network

  radarr:
    image: linuxserver/radarr:latest
    container_name: ${name}-radarr
    restart: unless-stopped
    ports:
      - "7878:7878"
    volumes:
      - radarr-config:/config
      - ./media/movies:/movies
      - ./downloads:/downloads
    networks:
      - ${name}-network

networks:
  ${name}-network:
    driver: bridge

volumes:
  jellyfin-config:
  sonarr-config:
  radarr-config:
EOF
}

#-------------------------------------------------------------------------------
# Custom Stack Builder
#-------------------------------------------------------------------------------
os_builder_custom() {
    os_clear_screen
    os_banner_small
    
    os_menu_header "Custom Stack Builder"
    
    local stack_name
    stack_name=$(os_prompt "Stack name")
    
    [[ -z "$stack_name" ]] && return
    
    local stack_dir="${OS_DATA_DIR}/${OS_CURRENT_TARGET}/stacks/${stack_name}"
    mkdir -p "$stack_dir"
    
    # Start compose file
    cat > "${stack_dir}/docker-compose.yml" << EOF
version: "3.8"

services:
EOF
    
    local services=()
    
    while true; do
        echo ""
        os_select "Add component" \
            "Database (PostgreSQL/MySQL/MongoDB)" \
            "Web Server (Nginx/Caddy)" \
            "Cache (Redis/Memcached)" \
            "Application Server (Node/PHP)" \
            "Done - Generate Stack"
        
        case $OS_SELECTED_INDEX in
            0) _os_add_database_component "${stack_dir}" services ;;
            1) _os_add_webserver_component "${stack_dir}" services ;;
            2) _os_add_cache_component "${stack_dir}" services ;;
            3) _os_add_app_component "${stack_dir}" services ;;
            4|255) break ;;
        esac
    done
    
    # Add network
    cat >> "${stack_dir}/docker-compose.yml" << EOF

networks:
  ${stack_name}-network:
    driver: bridge
EOF
    
    os_success "Custom stack created: ${stack_name}"
    
    if os_confirm "Deploy this stack now?" "y"; then
        os_target_deploy "$stack_name"
    fi
}

_os_add_database_component() {
    local dir="$1"
    local -n svc_array=$2
    
    os_select "Select database" "PostgreSQL" "MySQL" "MongoDB" "MariaDB"
    
    local name image port
    
    case $OS_SELECTED_INDEX in
        0) name="postgres"; image="postgres:15-alpine"; port="5432" ;;
        1) name="mysql"; image="mysql:8.0"; port="3306" ;;
        2) name="mongodb"; image="mongo:6"; port="27017" ;;
        3) name="mariadb"; image="mariadb:10"; port="3306" ;;
        *) return ;;
    esac
    
    local password
    password=$(os_generate_password 24)
    
    cat >> "${dir}/docker-compose.yml" << EOF
  ${name}:
    image: ${image}
    container_name: \${COMPOSE_PROJECT_NAME:-stack}-${name}
    restart: unless-stopped
    environment:
      POSTGRES_PASSWORD: ${password}
      MYSQL_ROOT_PASSWORD: ${password}
      MONGO_INITDB_ROOT_PASSWORD: ${password}
    volumes:
      - ${name}-data:/var/lib/${name}
    networks:
      - \${COMPOSE_PROJECT_NAME:-stack}-network

EOF
    
    svc_array+=("$name")
}

_os_add_webserver_component() {
    local dir="$1"
    local -n svc_array=$2
    
    os_select "Select web server" "Nginx" "Caddy" "Traefik"
    
    local name image
    
    case $OS_SELECTED_INDEX in
        0) name="nginx"; image="nginx:alpine" ;;
        1) name="caddy"; image="caddy:alpine" ;;
        2) name="traefik"; image="traefik:v2.10" ;;
        *) return ;;
    esac
    
    cat >> "${dir}/docker-compose.yml" << EOF
  ${name}:
    image: ${image}
    container_name: \${COMPOSE_PROJECT_NAME:-stack}-${name}
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    networks:
      - \${COMPOSE_PROJECT_NAME:-stack}-network

EOF
    
    svc_array+=("$name")
}

_os_add_cache_component() {
    local dir="$1"
    local -n svc_array=$2
    
    os_select "Select cache" "Redis" "Memcached"
    
    local name image
    
    case $OS_SELECTED_INDEX in
        0) name="redis"; image="redis:alpine" ;;
        1) name="memcached"; image="memcached:alpine" ;;
        *) return ;;
    esac
    
    cat >> "${dir}/docker-compose.yml" << EOF
  ${name}:
    image: ${image}
    container_name: \${COMPOSE_PROJECT_NAME:-stack}-${name}
    restart: unless-stopped
    networks:
      - \${COMPOSE_PROJECT_NAME:-stack}-network

EOF
    
    svc_array+=("$name")
}

_os_add_app_component() {
    local dir="$1"
    local -n svc_array=$2
    
    os_select "Select runtime" "Node.js" "PHP-FPM" "Python"
    
    local name image
    
    case $OS_SELECTED_INDEX in
        0) name="node"; image="node:20-alpine" ;;
        1) name="php"; image="php:8.2-fpm-alpine" ;;
        2) name="python"; image="python:3.11-alpine" ;;
        *) return ;;
    esac
    
    cat >> "${dir}/docker-compose.yml" << EOF
  ${name}:
    image: ${image}
    container_name: \${COMPOSE_PROJECT_NAME:-stack}-${name}
    restart: unless-stopped
    volumes:
      - ./app:/app
    working_dir: /app
    networks:
      - \${COMPOSE_PROJECT_NAME:-stack}-network

EOF
    
    svc_array+=("$name")
}

#-------------------------------------------------------------------------------
# Stack Management
#-------------------------------------------------------------------------------
os_builder_manage() {
    os_target_list
    
    echo ""
    read -rp "Press Enter to continue..."
}

#-------------------------------------------------------------------------------
# Initialization Flag
#-------------------------------------------------------------------------------
OS_BUILDER_LOADED=true
