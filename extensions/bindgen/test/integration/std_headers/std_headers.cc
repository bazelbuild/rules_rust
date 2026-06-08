#include "std_headers.h"

int64_t get_random_value() {
    // Use a stdlib function to ensure it's not optimized away and stdlib is
    // linked
    return abs(-42);
}
