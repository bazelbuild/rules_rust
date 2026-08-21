#include <assert.h>

#include "test/collide_c.h"

int main(void) {
    struct ValueA a = {1};
    struct ValueB b = {2};
    assert(collide_sum(a, b) == 3);

    return 0;
}
