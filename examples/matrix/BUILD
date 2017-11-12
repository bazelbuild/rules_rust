package(default_visibility = ["//visibility:public"])

load("@//rust:rust.bzl", "rust_library", "rust_test", "rust_binary")

rust_library(
    name = "matrix",
    srcs = [
        "src/ffi.rs",
        "src/lib.rs",
        "src/matrix.rs",
    ],
    deps = [
        "@libc//:libc",
        "//matrix/c:native_matrix",
    ],
)

rust_test(
    name = "matrix_test",
    deps = [":matrix"],
)

## Do the same as above, but with a dynamic c library.

rust_library(
    name = "matrix_dynamically_linked",
    srcs = [
        "src/ffi.rs",
        "src/lib.rs",
        "src/matrix.rs",
    ],
    deps = [
        "@libc//:libc",
        "//matrix/c:native_matrix_so",
    ],
)

rust_test(
    name = "matrix_dylib_test",
    deps = [":matrix_dynamically_linked"],
)
