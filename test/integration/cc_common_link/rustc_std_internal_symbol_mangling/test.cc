#include <cstdio>

extern "C" int rdep();

int main() {
    if (rdep() != 1001) {
        return 1;
    }
    return 0;
}
