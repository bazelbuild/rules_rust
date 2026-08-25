#include "test/simple_cc.h"

#include <cassert>

int main() {
    assert(simple_cc::simple_add(1, 2) == 3);

    simple_cc::Point point = simple_cc::simple_point_new(4, 5);
    assert(point.x == 4);
    assert(point.y == 5);

    return 0;
}
