#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  OmniScript - APK Package Manager Adapter (Alpine Linux)                   ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

[[ -n "${_OS_PKG_APK_LOADED:-}" ]] && return 0
readonly _OS_PKG_APK_LOADED=1

pkg_update() {
    os_sudo apk update -q
}

pkg_install() {
    os_sudo apk add -q "$@"
}

pkg_remove() {
    os_sudo apk del "$@"
}

pkg_purge() {
    os_sudo apk del --purge "$@"
}

pkg_upgrade() {
    os_sudo apk upgrade -q "$@"
}

pkg_search() {
    apk search "$1" | head -20
}

pkg_info() {
    apk info -a "$1"
}

pkg_list_installed() {
    apk list -I
}

pkg_is_installed() {
    apk info -e "$1" &>/dev/null
}

pkg_add_repo() {
    local repo="$1"
    echo "$repo" | os_sudo tee -a /etc/apk/repositories
    pkg_update
}
