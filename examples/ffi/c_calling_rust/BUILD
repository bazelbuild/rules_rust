load("@rules_cc//cc:defs.bzl", "cc_test")
load("@io_bazel_rules_rust//rust:rust.bzl", "rust_library")

rust_library(
    name = "rusty",
    srcs = ["lib.rs"],
    crate_type = "staticlib",
)

cc_test(
    name = "main",
    srcs = ["main.c"],
    deps = [":rusty"],
)
