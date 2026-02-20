#include "string_utils.h"
#include <cassert>
#include <iostream>

int main() {
    std::cout << "Running test_string_concat..." << std::endl;

    // Test string concatenation
    assert(concat("hello", " world") == "hello world");
    assert(concat("", "") == "");
    assert(concat("test", "") == "test");
    assert(concat("", "test") == "test");
    assert(concat("foo", "bar") == "foobar");

    std::cout << "test_string_concat: PASSED" << std::endl;
    return 0;
}
