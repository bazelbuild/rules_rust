#include <stdio.h>

#include <iostream>

extern "C" int cc_double_value(int value);
extern "C" int rust_double_value(int value);

int main() {
    printf("Hello World!\n");
    std::cout << "CC: " << cc_double_value(5) << std::endl;
    std::cout << "Rust: " << rust_double_value(5) << std::endl;
    return 0;
}
