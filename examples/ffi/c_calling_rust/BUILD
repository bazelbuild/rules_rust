package(default_visibility = ["//visibility:private"])

load("@//rust:rust.bzl", "rust_library", "rust_test", "rust_binary")

rust_library(
    name = "rusty",
    srcs = ["lib.rs"],
    crate_type = "staticlib",
)

# cc_* rules expect cc_* deps, so we need to wrap our rust staticlib.
cc_library(
    name = "wrapper",
    srcs = [":rusty"],
)

cc_test(
    name = "main",
    srcs = ["main.c"],
    deps = [":wrapper"],
)
