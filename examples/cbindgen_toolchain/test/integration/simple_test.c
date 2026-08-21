#include <assert.h>

#include "test/integration/simple_cbindgen.h"

int main(void) {
    assert(SIMPLE_VALUE == 42);
    assert(simple_function() == 1337);

    return 0;
}
