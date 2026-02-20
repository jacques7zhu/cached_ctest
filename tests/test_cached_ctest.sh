#!/usr/bin/env bash

# Integration test script for cached_ctest
# Automates all TDD scenarios to verify functionality

set -euo pipefail

# ============================================
# Configuration
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
EXAMPLE_DIR="${PROJECT_ROOT}/example"
BUILD_DIR="${EXAMPLE_DIR}/build_test"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# ============================================
# Utility Functions
# ============================================

log() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

success() {
    echo -e "${GREEN}[PASS]${NC} $*"
    ((TESTS_PASSED++))
}

fail() {
    echo -e "${RED}[FAIL]${NC} $*"
    ((TESTS_FAILED++))
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

section() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$*${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# ============================================
# Test Helpers
# ============================================

cleanup() {
    log "Cleaning up test environment..."
    rm -rf "${BUILD_DIR}"
}

setup() {
    log "Setting up test environment..."
    cleanup
    mkdir -p "${BUILD_DIR}"
    cd "${BUILD_DIR}"
}

run_cmake() {
    log "Running cmake..."
    cmake .. > /dev/null 2>&1
}

run_build() {
    log "Running build..."
    cmake --build . > /dev/null 2>&1
}

run_cached_ctest() {
    "${PROJECT_ROOT}/cached_ctest" "$@"
}

count_tests_run() {
    local output="$1"
    echo "$output" | grep "Tests to run:" | grep -oE '[0-9]+' | head -1
}

count_tests_cached() {
    local output="$1"
    echo "$output" | grep "Tests cached:" | grep -oE '[0-9]+' | head -1
}

# ============================================
# Test Scenarios
# ============================================

test_scenario_1_initial_build() {
    section "Scenario 1: Initial Build"

    setup
    run_cmake
    run_build

    log "Running cached_ctest for the first time..."
    local output
    output=$(run_cached_ctest 2>&1 || true)

    log "Checking results..."
    local tests_run
    tests_run=$(count_tests_run "$output")

    if [[ "$tests_run" == "5" ]]; then
        success "Scenario 1: All 5 tests ran on initial build"
    else
        fail "Scenario 1: Expected 5 tests to run, got $tests_run"
    fi
}

test_scenario_2_no_modifications() {
    section "Scenario 2: No Modifications (All Cached)"

    log "Running cached_ctest again without modifications..."
    local output
    output=$(run_cached_ctest 2>&1 || true)

    log "Checking results..."
    local tests_run
    local tests_cached

    tests_run=$(count_tests_run "$output")
    tests_cached=$(count_tests_cached "$output")

    if [[ "$tests_run" == "0" ]] && [[ "$tests_cached" == "5" ]]; then
        success "Scenario 2: All tests cached (0 run, 5 cached)"
    else
        fail "Scenario 2: Expected 0 run, 5 cached. Got $tests_run run, $tests_cached cached"
    fi
}

test_scenario_3_modify_single_file() {
    section "Scenario 3: Modify Single Source File"

    log "Modifying math_utils.cpp..."
    sleep 1  # Ensure timestamp difference
    touch "${EXAMPLE_DIR}/src/math_utils.cpp"

    run_build

    log "Running cached_ctest..."
    local output
    output=$(run_cached_ctest 2>&1 || true)

    log "Checking results..."
    local tests_run
    local tests_cached

    tests_run=$(count_tests_run "$output")
    tests_cached=$(count_tests_cached "$output")

    # Should run math tests + integration (3 tests)
    # Should cache string tests (2 tests)
    if [[ "$tests_run" == "3" ]] && [[ "$tests_cached" == "2" ]]; then
        success "Scenario 3: Only math-related tests ran (3 run, 2 cached)"
    else
        fail "Scenario 3: Expected 3 run, 2 cached. Got $tests_run run, $tests_cached cached"
    fi
}

test_scenario_4_include_filter() {
    section "Scenario 4: Include Filter (-R)"

    log "Modifying all source files..."
    sleep 1
    touch "${EXAMPLE_DIR}"/src/*.cpp

    run_build

    log "Running cached_ctest with -R 'math_.*'..."
    local output
    output=$(run_cached_ctest -R "math_.*" 2>&1 || true)

    log "Checking results..."
    # Should only run tests matching "math_.*" pattern
    if echo "$output" | grep -q "test_math_add"; then
        if ! echo "$output" | grep -q "test_string"; then
            success "Scenario 4: Only math tests ran with -R filter"
        else
            fail "Scenario 4: String tests ran despite -R filter"
        fi
    else
        fail "Scenario 4: Math tests didn't run with -R filter"
    fi
}

test_scenario_5_exclude_filter() {
    section "Scenario 5: Exclude Filter (-E)"

    log "Running cached_ctest with -E 'integration'..."
    local output
    output=$(run_cached_ctest -E "integration" 2>&1 || true)

    log "Checking results..."
    # Should not run integration test
    if ! echo "$output" | grep -q "test_integration"; then
        if echo "$output" | grep -q "test_math" || echo "$output" | grep -q "test_string"; then
            success "Scenario 5: Integration test excluded with -E filter"
        else
            warn "Scenario 5: No tests ran (expected some unit tests)"
        fi
    else
        fail "Scenario 5: Integration test ran despite -E filter"
    fi
}

test_scenario_6_dry_run() {
    section "Scenario 6: Dry-run Mode"

    log "Modifying a file for dry-run test..."
    sleep 1
    touch "${EXAMPLE_DIR}/src/string_utils.cpp"
    run_build

    log "Running cached_ctest --dry-run..."
    local output
    output=$(run_cached_ctest --dry-run 2>&1 || true)

    log "Checking results..."
    if echo "$output" | grep -q "Dry run mode"; then
        if echo "$output" | grep -q "would run these tests"; then
            success "Scenario 6: Dry-run mode works correctly"
        else
            fail "Scenario 6: Dry-run didn't show test list"
        fi
    else
        fail "Scenario 6: Dry-run mode not activated"
    fi
}

test_scenario_7_verbose_mode() {
    section "Scenario 7: Verbose Mode"

    log "Running cached_ctest --verbose..."
    local output
    output=$(run_cached_ctest --verbose 2>&1 || true)

    log "Checking results..."
    if echo "$output" | grep -qE "(Modified:|Cached:)"; then
        success "Scenario 7: Verbose mode shows test status"
    else
        fail "Scenario 7: Verbose mode doesn't show expected output"
    fi
}

test_metadata_generation() {
    section "Additional Test: Metadata Generation"

    log "Checking metadata file..."
    if [[ -f "${BUILD_DIR}/.cached_ctest/tests_metadata.json" ]]; then
        success "Metadata file generated"

        log "Validating JSON format..."
        if jq empty "${BUILD_DIR}/.cached_ctest/tests_metadata.json" 2>/dev/null; then
            success "Metadata JSON is valid"

            local test_count
            test_count=$(jq '.tests | length' "${BUILD_DIR}/.cached_ctest/tests_metadata.json")
            if [[ "$test_count" == "5" ]]; then
                success "Metadata contains all 5 tests"
            else
                fail "Metadata contains $test_count tests, expected 5"
            fi
        else
            fail "Metadata JSON is invalid"
        fi
    else
        fail "Metadata file not found"
    fi
}

test_anchor_file() {
    section "Additional Test: Anchor File"

    log "Checking anchor file..."
    if [[ -f "${BUILD_DIR}/.cached_ctest/anchor_timestamp" ]]; then
        success "Anchor file exists"

        log "Checking anchor update after successful test run..."
        local anchor_before
        anchor_before=$(stat -c %Y "${BUILD_DIR}/.cached_ctest/anchor_timestamp" 2>/dev/null || stat -f %m "${BUILD_DIR}/.cached_ctest/anchor_timestamp" 2>/dev/null)

        sleep 2
        touch "${EXAMPLE_DIR}/src/math_utils.cpp"
        run_build
        run_cached_ctest > /dev/null 2>&1 || true

        local anchor_after
        anchor_after=$(stat -c %Y "${BUILD_DIR}/.cached_ctest/anchor_timestamp" 2>/dev/null || stat -f %m "${BUILD_DIR}/.cached_ctest/anchor_timestamp" 2>/dev/null)

        if [[ "$anchor_after" -gt "$anchor_before" ]]; then
            success "Anchor file updated after successful test run"
        else
            warn "Anchor file not updated (may be expected if tests failed)"
        fi
    else
        fail "Anchor file not found"
    fi
}

# ============================================
# Main Test Runner
# ============================================

main() {
    section "Cached CTest Integration Tests"

    log "Project root: ${PROJECT_ROOT}"
    log "Example dir: ${EXAMPLE_DIR}"
    log "Build dir: ${BUILD_DIR}"

    # Check dependencies
    if ! command -v jq &> /dev/null; then
        fail "jq is not installed. Cannot run tests."
        exit 1
    fi

    if ! command -v cmake &> /dev/null; then
        fail "cmake is not installed. Cannot run tests."
        exit 1
    fi

    # Run all test scenarios
    test_scenario_1_initial_build
    test_scenario_2_no_modifications
    test_scenario_3_modify_single_file
    test_scenario_4_include_filter
    test_scenario_5_exclude_filter
    test_scenario_6_dry_run
    test_scenario_7_verbose_mode

    # Additional validation tests
    test_metadata_generation
    test_anchor_file

    # Cleanup
    cleanup

    # Summary
    section "Test Summary"
    echo -e "${GREEN}Passed:${NC} ${TESTS_PASSED}"
    echo -e "${RED}Failed:${NC} ${TESTS_FAILED}"
    echo ""

    if [[ ${TESTS_FAILED} -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed.${NC}"
        exit 1
    fi
}

# Run tests
main "$@"
