#include "math_utils.h"
#include <cassert>
#include <iostream>

int main() {
    std::cout << "Running test_math_multiply..." << std::endl;

    // Test basic multiplication
    assert(multiply(2, 3) == 6);
    assert(multiply(-1, 5) == -5);
    assert(multiply(0, 100) == 0);
    assert(multiply(10, 10) == 100);
    assert(multiply(-3, -4) == 12);

    std::cout << "test_math_multiply: PASSED" << std::endl;
    return 0;
}
