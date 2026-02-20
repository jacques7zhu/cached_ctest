#include "math_utils.h"
#include <cassert>
#include <iostream>

int main() {
    std::cout << "Running test_math_add..." << std::endl;

    // Test basic addition
    assert(add(2, 3) == 5);
    assert(add(-1, 1) == 0);
    assert(add(0, 0) == 0);
    assert(add(100, 200) == 300);
    assert(add(-5, -10) == -15);

    std::cout << "test_math_add: PASSED" << std::endl;
    return 0;
}
