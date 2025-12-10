#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  OmniScript - Pacman Package Manager Adapter (Arch Linux)                  ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

[[ -n "${_OS_PKG_PACMAN_LOADED:-}" ]] && return 0
readonly _OS_PKG_PACMAN_LOADED=1

pkg_update() {
    os_sudo pacman -Sy --noconfirm
}

pkg_install() {
    os_sudo pacman -S --noconfirm --needed "$@"
}

pkg_remove() {
    os_sudo pacman -R --noconfirm "$@"
}

pkg_purge() {
    os_sudo pacman -Rns --noconfirm "$@"
}

pkg_upgrade() {
    os_sudo pacman -Syu --noconfirm
}

pkg_search() {
    pacman -Ss "$1" | head -20
}

pkg_info() {
    pacman -Si "$1" 2>/dev/null || pacman -Qi "$1"
}

pkg_list_installed() {
    pacman -Q
}

pkg_is_installed() {
    pacman -Q "$1" &>/dev/null
}
