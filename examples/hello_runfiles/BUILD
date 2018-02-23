package(default_visibility = ["//visibility:public"])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_library",
    "rust_binary",
    "rust_test",
)

rust_library(
    name = "runfiles",
    srcs = ["src/lib.rs"],
)

rust_binary(
    name = "hello_runfiles",
    srcs = ["src/main.rs"],
    data = ["data/sample.txt"],
    deps = [":runfiles"],
)

rust_test(
    name = "hello_runfiles_test",
    data = ["data/sample.txt"],
    deps = [":runfiles"],
)
