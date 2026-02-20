# CachedCTest.cmake
# CMake module for incremental testing support
#
# Auto-initializes when included and auto-finalizes after the including
# directory's CMakeLists.txt finishes processing. Requires CMake >= 3.19.
#
# Usage:
#   include(CachedCTest)          # auto-init + schedules auto-finalize
#   cached_ctest_add_test(...)    # register tests

# Prevent multiple inclusions within a single CMake configure run.
# include_guard(GLOBAL) resets on each new cmake invocation, so functions
# are always re-defined while the module body only executes once per run.
include_guard(GLOBAL)

# ============================================================================
# Public: cached_ctest_add_test
# ============================================================================
# Add a test with metadata tracking.
# Wraps standard add_test() and generates per-test JSON for cached_ctest script.
#
# Usage:
#   cached_ctest_add_test(
#       NAME <test_name>
#       COMMAND <executable> [args...]
#       [WORKING_DIRECTORY <dir>]
#   )
function(cached_ctest_add_test)
    cmake_parse_arguments(
        ARG                          # prefix
        ""                           # options (flags)
        "NAME;WORKING_DIRECTORY"     # one-value keywords
        "COMMAND"                    # multi-value keywords
        ${ARGN}
    )

    if(NOT ARG_NAME)
        message(FATAL_ERROR "cached_ctest_add_test: NAME is required")
    endif()

    if(NOT ARG_COMMAND)
        message(FATAL_ERROR "cached_ctest_add_test: COMMAND is required")
    endif()

    # Extract executable (first element of COMMAND)
    list(GET ARG_COMMAND 0 EXECUTABLE)

    # Call standard add_test() to maintain compatibility with ctest
    if(ARG_WORKING_DIRECTORY)
        add_test(
            NAME ${ARG_NAME}
            COMMAND ${ARG_COMMAND}
            WORKING_DIRECTORY ${ARG_WORKING_DIRECTORY}
        )
    else()
        add_test(
            NAME ${ARG_NAME}
            COMMAND ${ARG_COMMAND}
        )
    endif()

    # Get metadata directory (use CMAKE_BINARY_DIR directly for absolute path)
    set(METADATA_DIR "${CMAKE_BINARY_DIR}/.cached_ctest")

    # Determine if EXECUTABLE is a target or a plain path
    set(EXECUTABLE_PATH "")
    if(TARGET ${EXECUTABLE})
        # Use generator expression to resolve target file path at generation time
        set(EXECUTABLE_PATH "$<TARGET_FILE:${EXECUTABLE}>")

        # Track test target for dependency management
        get_property(TEST_TARGETS GLOBAL PROPERTY CACHED_CTEST_TEST_TARGETS)
        list(APPEND TEST_TARGETS ${EXECUTABLE})
        set_property(GLOBAL PROPERTY CACHED_CTEST_TEST_TARGETS "${TEST_TARGETS}")
    else()
        # Assume it's a direct path or command
        set(EXECUTABLE_PATH "${EXECUTABLE}")
    endif()

    # Default working directory to binary dir
    if(NOT ARG_WORKING_DIRECTORY)
        set(ARG_WORKING_DIRECTORY "${CMAKE_BINARY_DIR}")
    endif()

    # Generate per-test metadata JSON via file(GENERATE) so generator
    # expressions (e.g. $<TARGET_FILE:...>) are evaluated correctly.
    set(TEST_JSON_FILE "${METADATA_DIR}/meta_${ARG_NAME}.json")
    file(GENERATE
        OUTPUT "${TEST_JSON_FILE}"
        CONTENT "{
  \"name\": \"${ARG_NAME}\",
  \"executable\": \"${EXECUTABLE_PATH}\",
  \"working_directory\": \"${ARG_WORKING_DIRECTORY}\"
}"
    )

    message(STATUS "CachedCTest: Registered test '${ARG_NAME}'")
endfunction()

# ============================================================================
# Internal: auto-finalization (invoked via cmake_language DEFER)
# ============================================================================

function(_cached_ctest_finalize)
    get_property(_metadata_dir GLOBAL PROPERTY CACHED_CTEST_METADATA_DIR)
    get_property(_module_dir   GLOBAL PROPERTY CACHED_CTEST_MODULE_DIR)

    # Custom target that merges all per-test JSON files into tests_metadata.json.
    # Use -DVAR=val form (single argument) to avoid quoting issues with VERBATIM.
    add_custom_target(merge_test_metadata ALL
        COMMAND ${CMAKE_COMMAND}
                "-DMETADATA_DIR=${_metadata_dir}"
                -P "${_module_dir}/MergeTestMetadata.cmake"
        COMMENT "Merging test metadata"
        VERBATIM
    )

    message(STATUS "CachedCTest: Finalized - anchor updates only after successful test runs")
endfunction()

# ============================================================================
# Auto-initialization (runs once when this module is included)
# ============================================================================

# Capture module directory now; CMAKE_CURRENT_LIST_DIR is unavailable inside
# a deferred call, so persist it via a global property.
set_property(GLOBAL PROPERTY CACHED_CTEST_MODULE_DIR "${CMAKE_CURRENT_LIST_DIR}")

# Create metadata directory
set(_cached_ctest_metadata_dir "${CMAKE_BINARY_DIR}/.cached_ctest")
file(MAKE_DIRECTORY "${_cached_ctest_metadata_dir}")

# Store paths in global properties so all functions can access them
set_property(GLOBAL PROPERTY CACHED_CTEST_METADATA_DIR "${_cached_ctest_metadata_dir}")
set_property(GLOBAL PROPERTY CACHED_CTEST_ANCHOR_FILE  "${_cached_ctest_metadata_dir}/anchor_timestamp")
set_property(GLOBAL PROPERTY CACHED_CTEST_TEST_TARGETS "")

# Create anchor file on first configure (old timestamp → all tests run initially)
if(NOT EXISTS "${_cached_ctest_metadata_dir}/anchor_timestamp")
    file(TOUCH "${_cached_ctest_metadata_dir}/anchor_timestamp")
endif()

message(STATUS "CachedCTest: Initialized (metadata dir: ${_cached_ctest_metadata_dir})")

# Schedule _cached_ctest_finalize to run automatically after the including
# directory's CMakeLists.txt is fully processed. Requires CMake >= 3.19.
cmake_language(DEFER CALL _cached_ctest_finalize)
