#include "test/simple_c.h"

#include <assert.h>

int main(void) {
    assert(simple_add(1, 2) == 3);

    struct Point point = simple_point_new(4, 5);
    assert(point.x == 4);
    assert(point.y == 5);

    return 0;
}
