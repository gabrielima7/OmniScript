#!/usr/bin/env bash
#===============================================================================
#
#   ██████╗ ███╗   ███╗███╗   ██╗██╗███████╗ ██████╗██████╗ ██╗██████╗ ████████╗
#  ██╔═══██╗████╗ ████║████╗  ██║██║██╔════╝██╔════╝██╔══██╗██║██╔══██╗╚══██╔══╝
#  ██║   ██║██╔████╔██║██╔██╗ ██║██║███████╗██║     ██████╔╝██║██████╔╝   ██║   
#  ██║   ██║██║╚██╔╝██║██║╚██╗██║██║╚════██║██║     ██╔══██╗██║██╔═══╝    ██║   
#  ╚██████╔╝██║ ╚═╝ ██║██║ ╚████║██║███████║╚██████╗██║  ██║██║██║        ██║   
#   ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═══╝╚═╝╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝╚═╝        ╚═╝   
#
#  One-Liner Installer
#  curl -fsSL https://raw.githubusercontent.com/gabrielima7/OmniScript/main/install.sh | bash
#
#===============================================================================

set -euo pipefail

#-------------------------------------------------------------------------------
# Configuration
#-------------------------------------------------------------------------------
REPO="gabrielima7/OmniScript"
BRANCH="main"
INSTALL_DIR="${OS_INSTALL_DIR:-${HOME}/.omniscript}"
BIN_DIR="${HOME}/.local/bin"

# Colors
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_CYAN='\033[36m'
C_GREEN='\033[32m'
C_RED='\033[31m'
C_YELLOW='\033[33m'
C_DIM='\033[2m'

#-------------------------------------------------------------------------------
# Helper Functions
#-------------------------------------------------------------------------------
print_banner() {
    echo -e "${C_CYAN}"
    cat << 'EOF'
   ██████╗ ███╗   ███╗███╗   ██╗██╗███████╗ ██████╗██████╗ ██╗██████╗ ████████╗
  ██╔═══██╗████╗ ████║████╗  ██║██║██╔════╝██╔════╝██╔══██╗██║██╔══██╗╚══██╔══╝
  ██║   ██║██╔████╔██║██╔██╗ ██║██║███████╗██║     ██████╔╝██║██████╔╝   ██║   
  ██║   ██║██║╚██╔╝██║██║╚██╗██║██║╚════██║██║     ██╔══██╗██║██╔═══╝    ██║   
  ╚██████╔╝██║ ╚═╝ ██║██║ ╚████║██║███████║╚██████╗██║  ██║██║██║        ██║   
   ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═══╝╚═╝╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝╚═╝        ╚═╝   
EOF
    echo -e "${C_RESET}"
    echo -e "  ${C_DIM}Modular IaC Framework for Hybrid Deployments${C_RESET}"
    echo ""
}

info() { echo -e "${C_CYAN}[INFO]${C_RESET} $1"; }
success() { echo -e "${C_GREEN}[✓]${C_RESET} $1"; }
warn() { echo -e "${C_YELLOW}[!]${C_RESET} $1"; }
error() { echo -e "${C_RED}[✗]${C_RESET} $1" >&2; }
fatal() { error "$1"; exit 1; }

check_requirements() {
    local missing=()
    
    for cmd in curl tar; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        fatal "Missing required commands: ${missing[*]}"
    fi
}

detect_os() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        echo "${ID:-unknown}"
    else
        echo "unknown"
    fi
}

#-------------------------------------------------------------------------------
# Installation
#-------------------------------------------------------------------------------
download_and_install() {
    local temp_dir
    temp_dir=$(mktemp -d)
    
    info "Downloading OmniScript..."
    
    local url="https://github.com/${REPO}/archive/refs/heads/${BRANCH}.tar.gz"
    
    if curl -fsSL "$url" | tar -xz -C "$temp_dir"; then
        success "Downloaded successfully"
    else
        fatal "Failed to download OmniScript"
    fi
    
    info "Installing to ${INSTALL_DIR}..."
    
    # Remove old installation if exists
    rm -rf "${INSTALL_DIR}"
    
    # Move to install directory
    mv "${temp_dir}/OmniScript-${BRANCH}" "${INSTALL_DIR}"
    
    # Make scripts executable
    chmod +x "${INSTALL_DIR}/omniscript.sh"
    chmod +x "${INSTALL_DIR}/install.sh"
    
    rm -rf "$temp_dir"
    
    success "Installed to ${INSTALL_DIR}"
}

setup_path() {
    info "Setting up PATH..."
    
    mkdir -p "${BIN_DIR}"
    
    # Create symlink
    ln -sf "${INSTALL_DIR}/omniscript.sh" "${BIN_DIR}/omniscript"
    ln -sf "${INSTALL_DIR}/omniscript.sh" "${BIN_DIR}/os"
    
    success "Created symlinks in ${BIN_DIR}"
    
    # Add to PATH if not already there
    local shell_rc=""
    
    if [[ -f "${HOME}/.bashrc" ]]; then
        shell_rc="${HOME}/.bashrc"
    elif [[ -f "${HOME}/.zshrc" ]]; then
        shell_rc="${HOME}/.zshrc"
    fi
    
    if [[ -n "$shell_rc" ]]; then
        if ! grep -q "${BIN_DIR}" "$shell_rc" 2>/dev/null; then
            echo "" >> "$shell_rc"
            echo "# OmniScript" >> "$shell_rc"
            echo "export PATH=\"\${PATH}:${BIN_DIR}\"" >> "$shell_rc"
            
            success "Added ${BIN_DIR} to PATH in ${shell_rc}"
        fi
    fi
    
    # Export for current session
    export PATH="${PATH}:${BIN_DIR}"
}

install_dependencies() {
    info "Checking optional dependencies..."
    
    local os
    os=$(detect_os)
    
    local deps_to_install=()
    
    # Check for jq (recommended for JSON parsing)
    if ! command -v jq &> /dev/null; then
        deps_to_install+=("jq")
    fi
    
    if [[ ${#deps_to_install[@]} -gt 0 ]]; then
        warn "Recommended packages not installed: ${deps_to_install[*]}"
        
        echo ""
        echo -e "  Install with:"
        
        case "$os" in
            ubuntu|debian|linuxmint|pop|zorin)
                echo -e "    ${C_DIM}sudo apt install ${deps_to_install[*]}${C_RESET}"
                ;;
            fedora|rhel|centos|rocky)
                echo -e "    ${C_DIM}sudo dnf install ${deps_to_install[*]}${C_RESET}"
                ;;
            arch|manjaro)
                echo -e "    ${C_DIM}sudo pacman -S ${deps_to_install[*]}${C_RESET}"
                ;;
            alpine)
                echo -e "    ${C_DIM}sudo apk add ${deps_to_install[*]}${C_RESET}"
                ;;
            *)
                echo -e "    ${C_DIM}Install: ${deps_to_install[*]}${C_RESET}"
                ;;
        esac
        echo ""
    else
        success "All recommended dependencies installed"
    fi
}

print_success() {
    echo ""
    echo -e "${C_GREEN}╔════════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "${C_GREEN}║          OmniScript installed successfully! 🚀             ║${C_RESET}"
    echo -e "${C_GREEN}╚════════════════════════════════════════════════════════════╝${C_RESET}"
    echo ""
    echo -e "  ${C_BOLD}Quick Start:${C_RESET}"
    echo -e "    ${C_CYAN}omniscript${C_RESET}        # Launch interactive TUI"
    echo -e "    ${C_CYAN}os${C_RESET}                # Shorthand alias"
    echo ""
    echo -e "  ${C_BOLD}Commands:${C_RESET}"
    echo -e "    ${C_CYAN}omniscript search nginx${C_RESET}     # Search for applications"
    echo -e "    ${C_CYAN}omniscript install redis${C_RESET}    # Install a module"
    echo -e "    ${C_CYAN}omniscript --help${C_RESET}           # Show all options"
    echo ""
    echo -e "  ${C_DIM}Restart your terminal or run: source ~/.bashrc${C_RESET}"
    echo ""
}

run_omniscript() {
    # Handle stdin for curl | bash
    if [[ ! -t 0 ]]; then
        exec < /dev/tty
    fi
    
    echo ""
    read -rp "Launch OmniScript now? [Y/n] " response
    response="${response:-y}"
    
    if [[ "${response,,}" == "y" ]] || [[ "${response,,}" == "yes" ]]; then
        exec "${INSTALL_DIR}/omniscript.sh"
    else
        echo ""
        echo "Exiting..."
        exit 0
    fi
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------
main() {
    print_banner
    
    check_requirements
    
    info "Installing OmniScript..."
    echo ""
    
    download_and_install
    setup_path
    install_dependencies
    
    print_success
    
    run_omniscript
}

# Handle --help
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    cat << EOF
OmniScript Installer

Usage: curl -fsSL https://raw.githubusercontent.com/${REPO}/${BRANCH}/install.sh | bash

Options:
    OS_INSTALL_DIR=/path    Set custom installation directory (default: ~/.omniscript)

Environment Variables:
    OS_INSTALL_DIR          Installation directory
    
Examples:
    # Default installation
    curl -fsSL https://raw.githubusercontent.com/${REPO}/${BRANCH}/install.sh | bash
    
    # Custom directory
    OS_INSTALL_DIR=/opt/omniscript curl -fsSL https://raw.githubusercontent.com/${REPO}/${BRANCH}/install.sh | sudo bash

EOF
    exit 0
fi

main "$@"
