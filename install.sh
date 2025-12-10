#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  OmniScript - One-Liner Installer                                          ║
# ║  Usage: curl -sSL https://raw.githubusercontent.com/.../install.sh | bash  ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

set -euo pipefail

# Configuration
REPO_URL="${OMNISCRIPT_REPO:-https://github.com/gabrielima7/OmniScript}"
INSTALL_DIR="${OMNISCRIPT_DIR:-/opt/omniscript}"
BRANCH="${OMNISCRIPT_BRANCH:-main}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Functions
print_banner() {
    cat << 'EOF'
   ____                  _ _____           _       _   
  / __ \                (_)  __ \         (_)     | |  
 | |  | |_ __ ___  _ __  _| (___  ___ _ __ _ _ __ | |_ 
 | |  | | '_ ` _ \| '_ \| |\___ \/ __| '__| | '_ \| __|
 | |__| | | | | | | | | | |____) \__ \ |  | | |_) | |_ 
  \____/|_| |_| |_|_| |_|_|_____/|___/_|  |_| .__/ \__|
                                            | |        
                                            |_|        
EOF
    echo -e "${CYAN}  Modular IaC Framework Installer${NC}"
    echo ""
}

log_info() { echo -e "${CYAN}ℹ️  $*${NC}"; }
log_success() { echo -e "${GREEN}✅ $*${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️  $*${NC}"; }
log_error() { echo -e "${RED}❌ $*${NC}" >&2; }

check_requirements() {
    local required=(curl git)
    
    for cmd in "${required[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            log_error "$cmd is required but not installed"
            exit 1
        fi
    done
}

detect_os() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

install_dependencies() {
    local os_id
    os_id=$(detect_os)
    
    log_info "Installing dependencies for $os_id..."
    
    case "$os_id" in
        debian|ubuntu|linuxmint|pop|zorin)
            sudo apt-get update -qq
            sudo apt-get install -y -qq curl git jq
            ;;
        fedora|rhel|centos|rocky|alma)
            sudo dnf install -y -q curl git jq
            ;;
        alpine)
            sudo apk add -q curl git jq bash
            ;;
        arch|manjaro)
            sudo pacman -Sy --noconfirm curl git jq
            ;;
        opensuse*)
            sudo zypper install -y curl git jq
            ;;
    esac
}

install_omniscript() {
    log_info "Installing OmniScript to $INSTALL_DIR..."
    
    # Always remove old version to ensure fresh install
    if [[ -d "$INSTALL_DIR" ]]; then
        log_info "Removing old installation..."
        sudo rm -rf "$INSTALL_DIR"
    fi
    
    # Create directory
    sudo mkdir -p "$INSTALL_DIR"
    
    # Download fresh copy
    log_info "Downloading OmniScript..."
    
    # Try git clone first
    if command -v git &>/dev/null; then
        sudo git clone --depth 1 -b "$BRANCH" "$REPO_URL" "$INSTALL_DIR" 2>/dev/null || {
            # Fallback: download archive
            curl -sSL "${REPO_URL}/archive/refs/heads/${BRANCH}.tar.gz" | sudo tar -xz -C /opt/
            sudo mv "/opt/OmniScript-${BRANCH}" "$INSTALL_DIR"
        }
    else
        # No git, use curl
        curl -sSL "${REPO_URL}/archive/refs/heads/${BRANCH}.tar.gz" | sudo tar -xz -C /opt/
        sudo mv "/opt/OmniScript-${BRANCH}" "$INSTALL_DIR"
    fi
    
    # Make executable
    sudo chmod +x "$INSTALL_DIR/omniscript.sh"
    
    # Create symlink
    sudo ln -sf "$INSTALL_DIR/omniscript.sh" /usr/local/bin/omniscript
    
    # Create config directory
    mkdir -p "$HOME/.config/omniscript"
}

create_uninstaller() {
    sudo cat > "$INSTALL_DIR/uninstall.sh" << 'UNINSTALL_EOF'
#!/usr/bin/env bash
echo "Uninstalling OmniScript..."
sudo rm -f /usr/local/bin/omniscript
sudo rm -rf /opt/omniscript
rm -rf "$HOME/.config/omniscript"
echo "✅ OmniScript uninstalled"
UNINSTALL_EOF
    sudo chmod +x "$INSTALL_DIR/uninstall.sh"
}

main() {
    print_banner
    
    # Check if running as root (warn but continue)
    if [[ $EUID -eq 0 ]]; then
        log_warn "Running as root. OmniScript will be installed system-wide."
    fi
    
    check_requirements
    install_dependencies
    install_omniscript
    create_uninstaller
    
    echo ""
    log_success "OmniScript installed successfully!"
    echo ""
    
    # Auto-start OmniScript interactive mode
    echo -e "${CYAN}Starting OmniScript...${NC}"
    echo ""
    
    # Reopen stdin from terminal for interactive input
    exec < /dev/tty
    
    # Run OmniScript (not exec, to keep tty attached)
    "$INSTALL_DIR/omniscript.sh"
}

# Handle arguments
case "${1:-}" in
    --uninstall)
        if [[ -f "$INSTALL_DIR/uninstall.sh" ]]; then
            sudo "$INSTALL_DIR/uninstall.sh"
        else
            log_error "OmniScript not installed or uninstaller not found"
        fi
        ;;
    --help|-h)
        echo "OmniScript Installer"
        echo ""
        echo "Usage: curl -sSL <url>/install.sh | bash [-s -- OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --uninstall    Remove OmniScript"
        echo "  --help         Show this help"
        echo ""
        echo "Environment variables:"
        echo "  OMNISCRIPT_DIR     Installation directory (default: /opt/omniscript)"
        echo "  OMNISCRIPT_REPO    Git repository URL"
        echo "  OMNISCRIPT_BRANCH  Git branch (default: main)"
        ;;
    *)
        main
        ;;
esac
