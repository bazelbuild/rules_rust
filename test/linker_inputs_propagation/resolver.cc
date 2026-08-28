#include <assert.h>
#include <stdlib.h>

extern "C" const void* resolver_symbol();

int main() {
    assert(resolver_symbol() != nullptr);
    return EXIT_SUCCESS;
}
