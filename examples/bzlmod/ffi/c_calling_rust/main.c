#include <assert.h>
#include <stdint.h>

extern int32_t my_favorite_number();

int main(int argc, char** argv) {
    assert(my_favorite_number() == 4);
    return 0;
}
