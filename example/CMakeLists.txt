cmake_minimum_required(VERSION 3.15)
project(CachedCTestExample CXX)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Enable testing
enable_testing()

# Include CachedCTest module
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/../cmake")
include(CachedCTest)

# Initialize cached_ctest system
cached_ctest_init()

# ============================================
# Libraries
# ============================================

# Math utilities library
add_library(math_utils src/math_utils.cpp)
target_include_directories(math_utils PUBLIC src)

# String utilities library
add_library(string_utils src/string_utils.cpp)
target_include_directories(string_utils PUBLIC src)

# ============================================
# Tests
# ============================================

# Helper function to create a test
function(add_example_test TEST_NAME SOURCE_FILE)
    # Create executable
    add_executable(${TEST_NAME} tests/${SOURCE_FILE})

    # Link libraries (passed as additional arguments)
    if(ARGC GREATER 2)
        target_link_libraries(${TEST_NAME} PRIVATE ${ARGN})
    endif()

    # Register with cached_ctest
    cached_ctest_add_test(
        NAME ${TEST_NAME}
        COMMAND ${TEST_NAME}
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    )
endfunction()

# Add math tests
add_example_test(test_math_add test_math_add.cpp math_utils)
add_example_test(test_math_multiply test_math_multiply.cpp math_utils)

# Add string tests
add_example_test(test_string_reverse test_string_reverse.cpp string_utils)
add_example_test(test_string_concat test_string_concat.cpp string_utils)

# Add integration test (uses both libraries)
add_example_test(test_integration test_integration.cpp math_utils string_utils)

# ============================================
# Finalize
# ============================================

# Finalize cached_ctest (merge metadata, set up dependencies)
cached_ctest_finalize()

# Print configuration summary
message(STATUS "")
message(STATUS "CachedCTest Example Configuration Summary:")
message(STATUS "  Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "  C++ standard: ${CMAKE_CXX_STANDARD}")
message(STATUS "  Binary directory: ${CMAKE_BINARY_DIR}")
message(STATUS "  Tests registered: 5")
message(STATUS "")
message(STATUS "To build and run tests:")
message(STATUS "  1. Build:    cmake --build .")
message(STATUS "  2. Run all:  ../cached_ctest")
message(STATUS "  3. Rebuild:  cmake --build . && ../cached_ctest")
message(STATUS "")
