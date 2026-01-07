#!/usr/bin/env bats
#===============================================================================
# OmniScript - Security Features Unit Tests
#===============================================================================

setup() {
    export OS_SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export OS_LIB_DIR="${OS_SCRIPT_DIR}/lib"
    export OS_DATA_DIR="${BATS_TMPDIR}/omniscript-test"
    export OS_SECRETS_DIR="${OS_DATA_DIR}/.secrets"
    export OS_LOG_FILE="${OS_DATA_DIR}/test.log"
    
    mkdir -p "$OS_DATA_DIR"
    
    load '../test_helper/bats-support/load'
    load '../test_helper/bats-assert/load'
    
    source "${OS_LIB_DIR}/core/ui.sh"
    source "${OS_LIB_DIR}/core/utils.sh"
    source "${OS_LIB_DIR}/features/security.sh"
}

teardown() {
    rm -rf "${OS_DATA_DIR}"
}

#-------------------------------------------------------------------------------
# Password Generation Tests
#-------------------------------------------------------------------------------
@test "os_generate_password creates password of correct length" {
    password=$(os_generate_password 16)
    assert_equal ${#password} 16
}

@test "os_generate_password creates unique passwords" {
    pw1=$(os_generate_password 32)
    pw2=$(os_generate_password 32)
    
    assert [ "$pw1" != "$pw2" ]
}

@test "os_generate_password_alnum creates alphanumeric password" {
    password=$(os_generate_password_alnum 20)
    assert_equal ${#password} 20
    
    # Should only contain alphanumeric characters
    [[ "$password" =~ ^[A-Za-z0-9]+$ ]]
}

@test "os_generate_password_simple creates simple password" {
    password=$(os_generate_password_simple 12)
    assert_equal ${#password} 12
    
    # Should only contain lowercase and numbers
    [[ "$password" =~ ^[a-z0-9]+$ ]]
}

@test "os_generate_uuid creates valid UUID format" {
    uuid=$(os_generate_uuid)
    
    # UUID format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    [[ "$uuid" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]
}

#-------------------------------------------------------------------------------
# Secrets Management Tests
#-------------------------------------------------------------------------------
@test "os_secrets_init creates secrets directory" {
    os_secrets_init
    assert [ -d "${OS_SECRETS_DIR}" ]
}

@test "os_secret_set stores a secret" {
    os_secret_set "test_key" "test_value"
    
    # Verify file was created
    assert [ -f "${OS_SECRETS_DIR}/secrets.enc" ]
}

@test "os_secret_get retrieves stored secret" {
    os_secret_set "retrieve_key" "retrieve_value"
    result=$(os_secret_get "retrieve_key")
    
    assert_equal "$result" "retrieve_value"
}

@test "os_secret_get returns default for missing key" {
    result=$(os_secret_get "nonexistent_key" "default")
    assert_equal "$result" "default"
}

@test "os_secret_delete removes a secret" {
    os_secret_set "delete_key" "delete_value"
    os_secret_delete "delete_key"
    
    result=$(os_secret_get "delete_key" "deleted")
    assert_equal "$result" "deleted"
}

@test "os_get_or_create_password creates and stores password" {
    password=$(os_get_or_create_password "new_service")
    
    assert [ -n "$password" ]
    
    # Should return same password on second call
    password2=$(os_get_or_create_password "new_service")
    assert_equal "$password" "$password2"
}

#-------------------------------------------------------------------------------
# Password Strength Tests
#-------------------------------------------------------------------------------
@test "os_validate_password_strength accepts strong password" {
    run os_validate_password_strength "MyStr0ng!Pass#2024"
    assert_success
}

@test "os_validate_password_strength rejects short password" {
    run os_validate_password_strength "short"
    assert_failure
}

#-------------------------------------------------------------------------------
# Security Checks Tests
#-------------------------------------------------------------------------------
@test "os_check_permissions detects correct permissions" {
    test_file="${OS_DATA_DIR}/test_perms"
    touch "$test_file"
    chmod 600 "$test_file"
    
    run os_check_permissions "$test_file" "600"
    assert_success
}

@test "os_harden_file sets correct permissions" {
    test_file="${OS_DATA_DIR}/test_harden"
    touch "$test_file"
    
    os_harden_file "$test_file" "600"
    
    perms=$(stat -c %a "$test_file")
    assert_equal "$perms" "600"
}
