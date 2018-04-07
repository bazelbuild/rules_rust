#include "ffi/rust_calling_c/greeter.h"

#include <iostream>

namespace greeter {

void greet() {
  std::cout << "Hello from C++!\n";
}

} // namespace greeter
