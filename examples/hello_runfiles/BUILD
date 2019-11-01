package(default_visibility = ["//visibility:public"])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_binary",
)

rust_binary(
    name = "hello_runfiles",
    srcs = ["hello_runfiles.rs"],
    data = ["hello_runfiles.rs"],  # Yes, we're being cute.
    edition = "2018",
    deps = ["@io_bazel_rules_rust//tools/runfiles"],
)
