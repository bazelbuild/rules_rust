package(default_visibility = ["//visibility:public"])

load("@//rust:rust.bzl", "rust_library", "rust_test")

cc_library(
    name = "native_matrix",
    srcs = ["src/matrix.c"],
    hdrs = ["src/matrix.h"],
    copts = ["-std=c99"],
)

cc_test(
    name = "native_matrix_test",
    srcs = ["src/matrix_test.c"],
    copts = ["-std=c99"],
    deps = [
        ":native_matrix",
    ],
)

rust_library(
    name = "matrix",
    srcs = [
        "src/ffi.rs",
        "src/lib.rs",
        "src/matrix.rs",
    ],
    deps = [
        ":native_matrix",
        "@libc//:libc",
    ],
)

rust_test(
    name = "matrix_test",
    deps = [":matrix"],
)
