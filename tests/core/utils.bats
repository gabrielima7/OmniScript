#!/usr/bin/env bats
#===============================================================================
# OmniScript - Core Utils Unit Tests
#===============================================================================

# Setup test environment
setup() {
    export OS_SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export OS_LIB_DIR="${OS_SCRIPT_DIR}/lib"
    export OS_DATA_DIR="${BATS_TMPDIR}/omniscript-test"
    export OS_CONFIG_FILE="${OS_DATA_DIR}/config.conf"
    export OS_LOG_FILE="${OS_DATA_DIR}/test.log"
    
    mkdir -p "$OS_DATA_DIR"
    
    # Load libraries
    load '../test_helper/bats-support/load'
    load '../test_helper/bats-assert/load'
    
    # Source the library under test
    source "${OS_LIB_DIR}/core/ui.sh"
    source "${OS_LIB_DIR}/core/utils.sh"
}

teardown() {
    rm -rf "${OS_DATA_DIR}"
}

#-------------------------------------------------------------------------------
# Logging Tests
#-------------------------------------------------------------------------------
@test "os_log creates log entry" {
    OS_VERBOSE=false
    os_log "INFO" "Test message"
    
    assert [ -f "${OS_LOG_FILE}" ]
    run grep "Test message" "${OS_LOG_FILE}"
    assert_success
}

@test "os_debug logs with DEBUG level" {
    OS_CURRENT_LOG_LEVEL="DEBUG"
    os_debug "Debug test"
    
    run grep "DEBUG.*Debug test" "${OS_LOG_FILE}"
    assert_success
}

#-------------------------------------------------------------------------------
# String Operations Tests
#-------------------------------------------------------------------------------
@test "os_trim removes leading/trailing whitespace" {
    result=$(os_trim "  hello world  ")
    assert_equal "$result" "hello world"
}

@test "os_to_lower converts to lowercase" {
    result=$(os_to_lower "HELLO WORLD")
    assert_equal "$result" "hello world"
}

@test "os_to_upper converts to uppercase" {
    result=$(os_to_upper "hello world")
    assert_equal "$result" "HELLO WORLD"
}

@test "os_slugify creates URL-safe slug" {
    result=$(os_slugify "Hello World! Test 123")
    assert_equal "$result" "hello-world-test-123"
}

#-------------------------------------------------------------------------------
# Port Operations Tests
#-------------------------------------------------------------------------------
@test "os_is_port_available returns true for high unused port" {
    run os_is_port_available 59999
    assert_success
}

@test "os_find_available_port returns a port number" {
    port=$(os_find_available_port 50000)
    assert [ "$port" -ge 50000 ]
}

#-------------------------------------------------------------------------------
# Config Operations Tests
#-------------------------------------------------------------------------------
@test "os_config_set writes config value" {
    os_config_set "TEST_KEY" "test_value"
    
    assert [ -f "${OS_CONFIG_FILE}" ]
    run grep "TEST_KEY" "${OS_CONFIG_FILE}"
    assert_success
}

@test "os_config_get reads config value" {
    os_config_set "TEST_KEY" "test_value"
    result=$(os_config_get "TEST_KEY")
    
    assert_equal "$result" "test_value"
}

@test "os_config_get returns default for missing key" {
    result=$(os_config_get "MISSING_KEY" "default_value")
    assert_equal "$result" "default_value"
}

#-------------------------------------------------------------------------------
# Version Comparison Tests
#-------------------------------------------------------------------------------
@test "os_version_compare eq works" {
    run os_version_compare "1.0.0" "eq" "1.0.0"
    assert_success
}

@test "os_version_compare gt works" {
    run os_version_compare "2.0.0" "gt" "1.0.0"
    assert_success
}

@test "os_version_compare lt works" {
    run os_version_compare "1.0.0" "lt" "2.0.0"
    assert_success
}

@test "os_version_compare handles v prefix" {
    run os_version_compare "v1.0.0" "eq" "1.0.0"
    assert_success
}

#-------------------------------------------------------------------------------
# Array Operations Tests
#-------------------------------------------------------------------------------
@test "os_array_contains finds element" {
    run os_array_contains "apple" "orange" "apple" "banana"
    assert_success
}

@test "os_array_contains fails for missing element" {
    run os_array_contains "grape" "orange" "apple" "banana"
    assert_failure
}

#-------------------------------------------------------------------------------
# Command Requirement Tests
#-------------------------------------------------------------------------------
@test "os_require_command succeeds for existing command" {
    run os_require_command "bash"
    assert_success
}

@test "os_require_command fails for missing command" {
    run os_require_command "nonexistent_command_xyz"
    assert_failure
}
