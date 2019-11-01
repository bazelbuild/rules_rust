load("@rules_cc//cc:defs.bzl", "cc_library", "cc_test")
load("@io_bazel_rules_rust//rust:rust.bzl", "rust_binary", "rust_library", "rust_test")

rust_library(
    name = "rusty",
    srcs = ["lib.rs"],
    crate_type = "staticlib",
)

# cc_* rules expect cc_* deps, so we need to wrap our rust staticlib.
cc_library(
    name = "wrapper",
    srcs = [":rusty"],
    # We could link dynamically by setting crate_type to cdylib
    linkstatic = True,
)

cc_test(
    name = "main",
    srcs = ["main.c"],
    deps = [":wrapper"],
)
