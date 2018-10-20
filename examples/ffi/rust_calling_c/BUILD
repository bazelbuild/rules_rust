package(default_visibility = ["//ffi/rust_calling_c:__subpackages__"])

load("@//rust:rust.bzl", "rust_library", "rust_test", "rust_binary", "rust_doc")

rust_library(
    name = "matrix",
    srcs = [
        "src/ffi.rs",
        "src/matrix.rs",
    ],
    deps = [
        "//ffi/rust_calling_c/c:native_matrix",
        "@libc",
    ],
)

rust_test(
    name = "matrix_test",
    deps = [":matrix"],
)

rust_doc(
    name = "matrix_doc",
    dep = ":matrix",
)

## Do the same as above, but with a dynamic c library.

rust_library(
    name = "matrix_dynamically_linked",
    srcs = [
        "src/ffi.rs",
        "src/matrix.rs",
    ],
    crate_root = "src/matrix.rs",
    deps = [
        "//ffi/rust_calling_c/c:native_matrix_so",
        "@libc",
    ],
)

rust_test(
    name = "matrix_dylib_test",
    deps = [":matrix_dynamically_linked"],
)

rust_doc(
    name = "matrix_dylib_doc",
    dep = ":matrix_dynamically_linked",
)
