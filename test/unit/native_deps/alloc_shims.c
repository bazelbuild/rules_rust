#include <stddef.h>
#include <stdlib.h>

void* __rdl_alloc(size_t, size_t);
void __rdl_dealloc(void*);
void* __rdl_realloc(void*, size_t, size_t, size_t);
void* __rdl_alloc_zeroed(size_t, size_t);
void* __attribute__((weak)) __rust_alloc(size_t a, size_t b) {
  return __rdl_alloc(a, b);
}
void __attribute__((weak)) __rust_dealloc(void* a) {
  __rdl_dealloc(a);
}
void* __attribute__((weak))
__rust_realloc(void* a, size_t b, size_t c, size_t d) {
  return __rdl_realloc(a, b, c, d);
}
void* __attribute__((weak)) __rust_alloc_zeroed(size_t a, size_t b) {
  return __rdl_alloc_zeroed(a, b);
}

void __rust_alloc_error_handler(void*whatever) {
        abort();
}
