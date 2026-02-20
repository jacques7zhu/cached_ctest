# CachedCTest.cmake
# CMake module for incremental testing support
#
# Provides functions to create cached test metadata and anchor file mechanism
# for timestamp-based incremental testing.

# Global variables to track state
if(NOT DEFINED CACHED_CTEST_INITIALIZED)
    set(CACHED_CTEST_INITIALIZED FALSE CACHE INTERNAL "")
endif()

# Initialize cached_ctest system
# Creates metadata directory and sets up anchor file update mechanism
function(cached_ctest_init)
    if(CACHED_CTEST_INITIALIZED)
        message(WARNING "cached_ctest_init() called multiple times")
        return()
    endif()

    set(CACHED_CTEST_INITIALIZED TRUE CACHE INTERNAL "")

    # Create metadata directory
    set(METADATA_DIR "${CMAKE_BINARY_DIR}/.cached_ctest")
    file(MAKE_DIRECTORY "${METADATA_DIR}")

    # Set global properties for other functions to access
    set_property(GLOBAL PROPERTY CACHED_CTEST_METADATA_DIR "${METADATA_DIR}")
    set_property(GLOBAL PROPERTY CACHED_CTEST_ANCHOR_FILE "${METADATA_DIR}/anchor_timestamp")
    set_property(GLOBAL PROPERTY CACHED_CTEST_TEST_TARGETS "")

    # Create anchor file if it doesn't exist (set to epoch time)
    set(ANCHOR_FILE "${METADATA_DIR}/anchor_timestamp")
    if(NOT EXISTS "${ANCHOR_FILE}")
        file(TOUCH "${ANCHOR_FILE}")
        # Set anchor to a very old timestamp so all tests run on first build
        execute_process(
            COMMAND ${CMAKE_COMMAND} -E touch_nocreate "${ANCHOR_FILE}"
        )
    endif()

    message(STATUS "CachedCTest: Initialized (metadata dir: ${METADATA_DIR})")
endfunction()

# Add a test with metadata tracking
# Wraps standard add_test() and generates metadata for cached_ctest script
#
# Usage:
#   cached_ctest_add_test(
#       NAME <test_name>
#       COMMAND <executable> [args...]
#       [WORKING_DIRECTORY <dir>]
#   )
function(cached_ctest_add_test)
    # Check initialization
    if(NOT CACHED_CTEST_INITIALIZED)
        message(FATAL_ERROR "cached_ctest_add_test() called before cached_ctest_init()")
    endif()

    # Parse arguments
    cmake_parse_arguments(
        ARG                          # prefix
        ""                           # options (flags)
        "NAME;WORKING_DIRECTORY"     # one-value keywords
        "COMMAND"                    # multi-value keywords
        ${ARGN}
    )

    # Validate required arguments
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

    # Get metadata directory (use CMAKE_BINARY_DIR directly to ensure absolute path)
    set(METADATA_DIR "${CMAKE_BINARY_DIR}/.cached_ctest")

    # Determine if EXECUTABLE is a target or a path
    set(EXECUTABLE_PATH "")
    if(TARGET ${EXECUTABLE})
        # Use generator expression to get target file path at generation time
        set(EXECUTABLE_PATH "$<TARGET_FILE:${EXECUTABLE}>")

        # Track test target for dependency management
        get_property(TEST_TARGETS GLOBAL PROPERTY CACHED_CTEST_TEST_TARGETS)
        list(APPEND TEST_TARGETS ${EXECUTABLE})
        set_property(GLOBAL PROPERTY CACHED_CTEST_TEST_TARGETS "${TEST_TARGETS}")
    else()
        # Assume it's a direct path or command
        set(EXECUTABLE_PATH "${EXECUTABLE}")
    endif()

    # Set working directory (default to binary dir if not specified)
    if(NOT ARG_WORKING_DIRECTORY)
        set(ARG_WORKING_DIRECTORY "${CMAKE_BINARY_DIR}")
    endif()

    # Generate test metadata JSON file using file(GENERATE)
    # This handles generator expressions like $<TARGET_FILE:...>
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

# Finalize cached_ctest setup
# Merges all individual test JSON files into single metadata file
# Sets up dependencies to ensure anchor is updated after all tests are built
function(cached_ctest_finalize)
    if(NOT CACHED_CTEST_INITIALIZED)
        message(WARNING "cached_ctest_finalize() called before cached_ctest_init()")
        return()
    endif()

    get_property(METADATA_DIR GLOBAL PROPERTY CACHED_CTEST_METADATA_DIR)

    # Add custom target to merge JSON files
    # This runs at build time to combine all meta_*.json into tests_metadata.json
    # Note: file(GENERATE) outputs are created at generation time, so they should exist during build
    add_custom_target(merge_test_metadata ALL
        COMMAND ${CMAKE_COMMAND}
                -D METADATA_DIR="${METADATA_DIR}"
                -P "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/MergeTestMetadata.cmake"
        COMMENT "Merging test metadata"
        VERBATIM
    )

    message(STATUS "CachedCTest: Finalized - anchor updates only after successful test runs")
endfunction()
