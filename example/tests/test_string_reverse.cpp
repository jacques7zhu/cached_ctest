#include "string_utils.h"
#include <cassert>
#include <iostream>

int main() {
    std::cout << "Running test_string_reverse..." << std::endl;

    // Test string reversal
    assert(reverse("hello") == "olleh");
    assert(reverse("") == "");
    assert(reverse("a") == "a");
    assert(reverse("12345") == "54321");
    assert(reverse("racecar") == "racecar");

    std::cout << "test_string_reverse: PASSED" << std::endl;
    return 0;
}
