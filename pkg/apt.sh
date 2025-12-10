#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  OmniScript - APT Package Manager Adapter (Debian/Ubuntu)                  ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

[[ -n "${_OS_PKG_APT_LOADED:-}" ]] && return 0
readonly _OS_PKG_APT_LOADED=1

pkg_update() {
    os_sudo apt-get update -qq
}

pkg_install() {
    os_sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$@"
}

pkg_remove() {
    os_sudo apt-get remove -y "$@"
}

pkg_purge() {
    os_sudo apt-get purge -y "$@"
    os_sudo apt-get autoremove -y
}

pkg_upgrade() {
    os_sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq "$@"
}

pkg_search() {
    apt-cache search "$1" | head -20
}

pkg_info() {
    apt-cache show "$1"
}

pkg_list_installed() {
    dpkg -l | grep "^ii"
}

pkg_is_installed() {
    dpkg -l "$1" 2>/dev/null | grep -q "^ii"
}

pkg_add_repo() {
    local repo="$1"
    os_sudo add-apt-repository -y "$repo"
    pkg_update
}

pkg_add_key() {
    local key_url="$1"
    local keyring="${2:-/etc/apt/keyrings/omniscript.gpg}"
    curl -fsSL "$key_url" | os_sudo gpg --dearmor -o "$keyring"
}
