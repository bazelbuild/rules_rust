load("@rules_rust//rust:defs.bzl", "rust_library", "rust_static_library")

package(default_visibility = ["//visibility:public"])

rust_library(
    name = "rust_library",
    srcs = ["rust_library.rs"],
    tags = ["platform_missing"],
    deps = [],
)

# CC needs to link against a Rust `staticlib` crate which includes
# all the Rust `std` symbols.
rust_static_library(
    name = "rust_library_cc",
    srcs = ["rust_library.rs"],
    tags = ["platform_missing"],
    deps = [],
)
