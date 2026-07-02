#include <cassert>

#include "test/simple-hyphenated.h"

#ifndef INCLUDE_SIMPLE_HYPHENATED_H
#error "The include guard derived from the hyphenated target name is missing"
#endif

int main() {
    assert(simple_hyphenated::simple_add(1, 2) == 3);

    simple_hyphenated::Point point = simple_hyphenated::simple_point_new(4, 5);
    assert(point.x == 4);
    assert(point.y == 5);

    return 0;
}
