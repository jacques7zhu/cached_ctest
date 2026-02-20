#include "string_utils.h"
#include <algorithm>

std::string reverse(const std::string& str) {
    std::string result = str;
    std::reverse(result.begin(), result.end());
    return result;

}

std::string concat(const std::string& a, const std::string& b) {
    return a + b;
}
