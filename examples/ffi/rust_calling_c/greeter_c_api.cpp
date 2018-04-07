#include "ffi/rust_calling_c/greeter.h"

extern "C" {

void greeter_greet() {
  greeter::greet();
}

} // extern "C"
