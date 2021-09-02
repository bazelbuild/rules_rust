#include <stdint.h>

#if defined(__APPLE__)
// https://github.com/bazelbuild/rules_rust/issues/899
#include <TargetConditionals.h>

const int8_t IS_MACOS = TARGET_OS_OSX;
#else
const int8_t IS_MACOS = 0;
#endif

const int64_t SIMPLE_VALUE = 42;
