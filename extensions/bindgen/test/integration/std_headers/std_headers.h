#ifndef __STD_HEADERS_H_INCLUDE__
#define __STD_HEADERS_H_INCLUDE__

#ifdef __cplusplus
#define EXTERN_C extern "C"
#else
#define EXTERN_C
#endif

#include <stdint.h>
#include <stdlib.h>

EXTERN_C int64_t get_random_value();

#endif
