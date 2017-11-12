cc_library(
    name = "native_matrix",
    srcs = ["matrix.c"],
    hdrs = ["matrix.h"],
    copts = ["-std=c99"],
    visibility = ["//visibility:public"],
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
    visibility = ["//visibility:public"],
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
