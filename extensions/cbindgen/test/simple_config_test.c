#include <assert.h>

#include "test/simple_config_custom.h"

#ifndef TEST_SIMPLE_CONFIG_H
#error "The custom include guard from the config template is missing"
#endif

int main(void) {
    assert(simple_add(1, 2) == 3);

    struct Point point = simple_point_new(4, 5);
    assert(point.x == 4);
    assert(point.y == 5);

    return 0;
}
