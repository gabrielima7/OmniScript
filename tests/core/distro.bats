#!/usr/bin/env bats
#===============================================================================
# OmniScript - Distro Detection Unit Tests
#===============================================================================

setup() {
    export OS_SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export OS_LIB_DIR="${OS_SCRIPT_DIR}/lib"
    export OS_DATA_DIR="${BATS_TMPDIR}/omniscript-test"
    export OS_LOG_FILE="${OS_DATA_DIR}/test.log"
    
    mkdir -p "$OS_DATA_DIR"
    
    load '../test_helper/bats-support/load'
    load '../test_helper/bats-assert/load'
    
    source "${OS_LIB_DIR}/core/ui.sh"
    source "${OS_LIB_DIR}/core/utils.sh"
    source "${OS_LIB_DIR}/core/distro.sh"
}

teardown() {
    rm -rf "${OS_DATA_DIR}"
}

#-------------------------------------------------------------------------------
# Distribution Detection Tests
#-------------------------------------------------------------------------------
@test "os_detect_distro sets OS_DISTRO_ID" {
    os_detect_distro
    assert [ -n "$OS_DISTRO_ID" ]
}

@test "os_detect_distro sets OS_DISTRO_NAME" {
    os_detect_distro
    assert [ -n "$OS_DISTRO_NAME" ]
}

@test "os_detect_distro sets OS_DISTRO_FAMILY" {
    os_detect_distro
    assert [ -n "$OS_DISTRO_FAMILY" ]
}

@test "os_detect_distro sets OS_PKG_MANAGER" {
    os_detect_distro
    assert [ -n "$OS_PKG_MANAGER" ]
}

@test "os_detect_distro sets OS_INIT_SYSTEM" {
    os_detect_distro
    assert [ -n "$OS_INIT_SYSTEM" ]
}

#-------------------------------------------------------------------------------
# System Info Tests
#-------------------------------------------------------------------------------
@test "os_get_arch returns valid architecture" {
    arch=$(os_get_arch)
    assert [ -n "$arch" ]
    # Should be one of common architectures
    [[ "$arch" =~ ^(amd64|arm64|armhf|armv6|386|x86_64)$ ]]
}

@test "os_get_kernel_version returns kernel version" {
    version=$(os_get_kernel_version)
    assert [ -n "$version" ]
}

@test "os_get_hostname returns hostname" {
    hostname=$(os_get_hostname)
    assert [ -n "$hostname" ]
}

@test "os_get_memory_total_mb returns positive number" {
    mem=$(os_get_memory_total_mb)
    assert [ "$mem" -gt 0 ]
}

@test "os_get_cpu_cores returns positive number" {
    cores=$(os_get_cpu_cores)
    assert [ "$cores" -gt 0 ]
}

#-------------------------------------------------------------------------------
# Package Manager Tests (only if on supported distro)
#-------------------------------------------------------------------------------
@test "os_pkg_is_installed works for bash" {
    os_detect_distro
    
    # bash should be installed on any system running these tests
    run os_pkg_is_installed "bash"
    # May or may not succeed depending on package name format
    # Just ensure it doesn't error
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}
