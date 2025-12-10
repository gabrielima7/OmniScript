#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  OmniScript - Zypper Package Manager Adapter (openSUSE)                    ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

[[ -n "${_OS_PKG_ZYPPER_LOADED:-}" ]] && return 0
readonly _OS_PKG_ZYPPER_LOADED=1

pkg_update() {
    os_sudo zypper refresh -q
}

pkg_install() {
    os_sudo zypper install -y -q "$@"
}

pkg_remove() {
    os_sudo zypper remove -y "$@"
}

pkg_purge() {
    os_sudo zypper remove -y --clean-deps "$@"
}

pkg_upgrade() {
    os_sudo zypper update -y -q "$@"
}

pkg_search() {
    zypper search "$1" | head -20
}

pkg_info() {
    zypper info "$1"
}

pkg_list_installed() {
    zypper packages --installed-only
}

pkg_is_installed() {
    zypper se -i "$1" 2>/dev/null | grep -q "^i"
}

pkg_add_repo() {
    local name="$1"
    local url="$2"
    os_sudo zypper addrepo -f "$url" "$name"
    pkg_update
}
