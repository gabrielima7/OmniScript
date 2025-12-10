#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  OmniScript - DNF Package Manager Adapter (Fedora/RHEL)                    ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

[[ -n "${_OS_PKG_DNF_LOADED:-}" ]] && return 0
readonly _OS_PKG_DNF_LOADED=1

pkg_update() {
    os_sudo dnf check-update -q || true
}

pkg_install() {
    os_sudo dnf install -y -q "$@"
}

pkg_remove() {
    os_sudo dnf remove -y "$@"
}

pkg_purge() {
    os_sudo dnf remove -y "$@"
    os_sudo dnf autoremove -y
}

pkg_upgrade() {
    os_sudo dnf upgrade -y -q "$@"
}

pkg_search() {
    dnf search "$1" 2>/dev/null | head -20
}

pkg_info() {
    dnf info "$1"
}

pkg_list_installed() {
    dnf list installed
}

pkg_is_installed() {
    dnf list installed "$1" &>/dev/null
}

pkg_add_repo() {
    local repo="$1"
    os_sudo dnf config-manager --add-repo "$repo"
}
