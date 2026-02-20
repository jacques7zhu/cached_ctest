# MergeTestMetadata.cmake
# CMake script to merge individual test JSON files into a single metadata file
#
# This script is executed at build time via cmake -P
# Expected variable: METADATA_DIR

if(NOT DEFINED METADATA_DIR)
    message(FATAL_ERROR "METADATA_DIR must be defined")
endif()

# Find all meta_*.json files
message(STATUS "Looking for test JSON files in: ${METADATA_DIR}")
file(GLOB TEST_JSON_FILES "${METADATA_DIR}/meta_*.json")
message(STATUS "Found files: ${TEST_JSON_FILES}")

if(NOT TEST_JSON_FILES)
    message(WARNING "No test JSON files found in ${METADATA_DIR}")
    # Create empty metadata file
    file(WRITE "${METADATA_DIR}/tests_metadata.json" "{
  \"tests\": [],
  \"metadata_version\": \"1.0\"
}
")
    return()
endif()

# Initialize test array content
set(ALL_TESTS "")
set(FIRST_ITEM TRUE)

# Read each test JSON file and extract content
foreach(JSON_FILE ${TEST_JSON_FILES})
    file(READ "${JSON_FILE}" JSON_CONTENT)

    # Strip any leading/trailing whitespace
    string(STRIP "${JSON_CONTENT}" JSON_CONTENT)

    # Add comma separator if not first item
    if(FIRST_ITEM)
        set(ALL_TESTS "    ${JSON_CONTENT}")
        set(FIRST_ITEM FALSE)
    else()
        set(ALL_TESTS "${ALL_TESTS},\n    ${JSON_CONTENT}")
    endif()
endforeach()

# Generate timestamp
string(TIMESTAMP CURRENT_TIME UTC)

# Write merged JSON file
file(WRITE "${METADATA_DIR}/tests_metadata.json" "{
  \"tests\": [
${ALL_TESTS}
  ],
  \"metadata_version\": \"1.0\",
  \"generated_at\": \"${CURRENT_TIME}\"
}
")

list(LENGTH TEST_JSON_FILES NUM_TESTS)
message(STATUS "Merged ${NUM_TESTS} test metadata files")
