#!/usr/bin/env bash
#===============================================================================
# OmniScript Module: Node.js
# Deploy Node.js development environment
#===============================================================================
# shellcheck disable=SC2034

#-------------------------------------------------------------------------------
# Module Metadata
#-------------------------------------------------------------------------------
OS_MODULE_NAME="nodejs"
OS_MODULE_VERSION="1.0.0"
OS_MODULE_DESCRIPTION="Node.js - JavaScript runtime for development"
OS_MODULE_CATEGORY="devtools"

#-------------------------------------------------------------------------------
# Default Configuration
#-------------------------------------------------------------------------------
NODE_VERSION="${NODE_VERSION:-20}"

#-------------------------------------------------------------------------------
# Docker Compose
#-------------------------------------------------------------------------------
os_module_compose() {
    cat << EOF
version: "3.8"

services:
  node:
    image: node:${NODE_VERSION}-alpine
    container_name: nodejs-dev
    restart: unless-stopped
    working_dir: /app
    volumes:
      - ./app:/app
      - node-modules:/app/node_modules
    ports:
      - "3000:3000"
      - "5173:5173"
    command: sh -c "npm install && npm run dev"
    environment:
      NODE_ENV: development

volumes:
  node-modules:
EOF
    
    os_info "Node.js ${NODE_VERSION} development container ready"
    os_info "Mount your project to ./app directory"
}

#-------------------------------------------------------------------------------
# Bare Metal Installation
#-------------------------------------------------------------------------------
os_module_baremetal() {
    os_info "Installing Node.js ${NODE_VERSION}..."
    
    case "${OS_DISTRO_FAMILY}" in
        debian)
            # Use NodeSource repository for latest versions
            curl -fsSL "https://deb.nodesource.com/setup_${NODE_VERSION}.x" | sudo -E bash -
            os_pkg_install "nodejs"
            ;;
        rhel)
            curl -fsSL "https://rpm.nodesource.com/setup_${NODE_VERSION}.x" | sudo bash -
            os_pkg_install "nodejs"
            ;;
        arch)
            os_pkg_install "nodejs npm"
            ;;
        alpine)
            os_pkg_install "nodejs npm"
            ;;
        *)
            os_error "Bare metal installation not supported for ${OS_DISTRO_ID}"
            os_info "Consider using nvm or Docker instead"
            return 1
            ;;
    esac
    
    # Install common global packages
    if os_confirm "Install common global packages (pnpm, yarn, typescript)?" "y"; then
        npm install -g pnpm yarn typescript ts-node nodemon
        os_success "Global packages installed"
    fi
    
    os_success "Node.js $(node --version) installed"
    os_info "npm version: $(npm --version)"
}

#-------------------------------------------------------------------------------
# NVM Installation (Alternative)
#-------------------------------------------------------------------------------
os_module_nvm() {
    os_info "Installing NVM (Node Version Manager)..."
    
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    
    export NVM_DIR="$HOME/.nvm"
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    nvm install "${NODE_VERSION}"
    nvm use "${NODE_VERSION}"
    nvm alias default "${NODE_VERSION}"
    
    os_success "NVM installed with Node.js ${NODE_VERSION}"
}
