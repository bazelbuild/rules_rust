load("@rules_cc//cc:defs.bzl", "cc_binary", "cc_library", "cc_test")

package(default_visibility = ["//ffi/rust_calling_c:__subpackages__"])

cc_library(
    name = "native_matrix",
    srcs = ["matrix.c"],
    hdrs = ["matrix.h"],
    copts = ["-std=c99"],
)

cc_test(
    name = "native_matrix_test",
    srcs = ["matrix_test.c"],
    copts = ["-std=c99"],
    deps = [
        ":native_matrix",
    ],
)

## Do the same as above, but with a dynamic c library.

cc_library(
    name = "native_matrix_so",
    srcs = [":libnative_matrix_so.so"],
    hdrs = ["matrix.h"],
)

cc_binary(
    name = "libnative_matrix_so.so",
    srcs = [
        "matrix.c",
        "matrix.h",
    ],
    copts = ["-std=c99"],
    linkshared = True,
)
