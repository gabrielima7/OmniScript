#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  OmniScript - Nginx Application Manifest                                   ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

APP_NAME="nginx"
APP_DESCRIPTION="High-performance HTTP server and reverse proxy"
APP_CATEGORY="webserver"
APP_WEBSITE="https://nginx.org"
APP_SERVICE="nginx"

# Images by target
DOCKER_IMAGE="nginx"
PODMAN_IMAGE="docker.io/library/nginx"
LXC_IMAGE="images:debian/bookworm"

# Packages by distro
APT_PACKAGES="nginx"
DNF_PACKAGES="nginx"
APK_PACKAGES="nginx"
PACMAN_PACKAGES="nginx"
ZYPPER_PACKAGES="nginx"

# Ports
PORTS=(80 443)

# Volumes
VOLUMES=(
    "${OS_CONFIG_DIR}/data/nginx/conf:/etc/nginx/conf.d"
    "${OS_CONFIG_DIR}/data/nginx/html:/usr/share/nginx/html"
    "${OS_CONFIG_DIR}/data/nginx/logs:/var/log/nginx"
)

# Environment
ENVIRONMENT=(
    "NGINX_HOST=\${APP_DOMAIN:-localhost}"
)

# Configurable options
CONFIGURABLE=(
    "DOMAIN:string:localhost:Domain name for Nginx"
    "SSL:bool:false:Enable SSL/HTTPS"
    "HTTP2:bool:true:Enable HTTP/2"
)

pre_install() {
    os_log_info "Preparing nginx installation..."
    
    # Create config directories
    os_ensure_dir "${OS_CONFIG_DIR}/data/nginx/conf"
    os_ensure_dir "${OS_CONFIG_DIR}/data/nginx/html"
    os_ensure_dir "${OS_CONFIG_DIR}/data/nginx/logs"
    
    # Create default index.html
    cat > "${OS_CONFIG_DIR}/data/nginx/html/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to OmniScript!</title>
    <style>
        body { font-family: system-ui; display: flex; justify-content: center; 
               align-items: center; height: 100vh; margin: 0; background: #1a1a2e; color: #eee; }
        .container { text-align: center; }
        h1 { color: #4cc9f0; }
        .emoji { font-size: 4rem; }
    </style>
</head>
<body>
    <div class="container">
        <div class="emoji">🚀</div>
        <h1>Welcome to OmniScript!</h1>
        <p>Nginx is running successfully.</p>
    </div>
</body>
</html>
EOF
}

post_install() {
    os_log_success "Nginx installed successfully!"
    os_store_credential "nginx_config" "${OS_CONFIG_DIR}/data/nginx/conf"
    os_store_credential "nginx_webroot" "${OS_CONFIG_DIR}/data/nginx/html"
}
