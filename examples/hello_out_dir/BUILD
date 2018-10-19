load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_binary",
    "rust_library",
    "rust_test",
)

rust_library(
    name = "hello_out_dir",
    srcs = ["src/lib.rs"],
    out_dir_tar = ":repacked_srcs.tar.gz",
)

rust_binary(
    name = "hello_out_dir_bin",
    srcs = ["src/main.rs"],
    out_dir_tar = ":repacked_srcs.tar.gz",
)

rust_test(
    name = "hello_out_dir_test",
    out_dir_tar = ":repacked_srcs.tar.gz",
    deps = [":hello_out_dir"],
)
