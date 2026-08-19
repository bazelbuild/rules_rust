load("@rules_rust//rust:defs.bzl", "rust_binary", "rust_dylib_library", "rust_test")

# Integration tests for rust_dylib_library: verifies that a binary depending
# on a Rust ABI dylib can be built and run, exercising runfiles inclusion
# and RPATH resolution end-to-end.

NOT_WINDOWS = select({
    "@platforms//os:linux": [],
    "@platforms//os:macos": [],
    "//conditions:default": ["@platforms//:incompatible"],
})

rust_dylib_library(
    name = "rust_dylib_lib",
    srcs = ["lib.rs"],
    edition = "2021",
    link_std_dylib = True,
    visibility = ["//test:__subpackages__"],
)

rust_binary(
    name = "dylib_dep_binary",
    srcs = ["main.rs"],
    deps = [":rust_dylib_lib"],
    edition = "2021",
    link_std_dylib = True,
    target_compatible_with = NOT_WINDOWS,
)

rust_test(
    name = "dylib_dep_test",
    srcs = ["main.rs"],
    deps = [":rust_dylib_lib"],
    edition = "2021",
    link_std_dylib = True,
    target_compatible_with = NOT_WINDOWS,
)
