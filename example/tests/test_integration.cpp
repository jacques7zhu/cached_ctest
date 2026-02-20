#include "math_utils.h"
#include "string_utils.h"
#include <cassert>
#include <iostream>
#include <string>

int main() {
    std::cout << "Running test_integration..." << std::endl;

    // Test integration of math and string utilities
    // Convert numbers to strings and manipulate them
    int sum = add(5, 3);  // 8
    int product = multiply(2, 4);  // 8

    // Verify math operations
    assert(sum == 8);
    assert(product == 8);

    // Test string operations
    std::string hello = "hello";
    std::string world = "world";
    std::string combined = concat(hello, world);  // "helloworld"
    std::string reversed = reverse(combined);  // "dlrowolleh"

    assert(combined == "helloworld");
    assert(reversed == "dlrowolleh");

    // Combined test: reverse and concat
    std::string rev_hello = reverse(hello);  // "olleh"
    std::string final_str = concat(rev_hello, world);  // "ollehworld"
    assert(final_str == "ollehworld");

    std::cout << "test_integration: PASSED" << std::endl;
    return 0;
}
