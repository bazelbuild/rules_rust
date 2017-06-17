package(default_visibility = ["//visibility:public"])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_library",
    "rust_test",
)

rust_library(
    name = "hello_out_dir",
    srcs = ["src/lib.rs"],
)

rust_test(
    name = "hello_out_dir_test",
    out_dir_tar = ":repacked_srcs.tar.gz",
    deps = [":hello_out_dir"],
)
