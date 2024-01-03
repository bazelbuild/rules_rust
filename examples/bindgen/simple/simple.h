#ifndef __SIMPLE_H_INCLUDE__
#define __SIMPLE_H_INCLUDE__

#ifdef __cplusplus
#define EXTERN_C extern "C"
#else
#define EXTERN_C
#endif

#include <stdint.h>

EXTERN_C const int64_t SIMPLE_VALUE = 42;

EXTERN_C const int64_t simple_function();

#endif
