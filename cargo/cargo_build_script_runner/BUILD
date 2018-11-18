load("//rust:rust.bzl", "rust_library", "rust_binary", "rust_test")

rust_library(
    name = "cargo_build_script_output_parser",
    srcs = ["lib.rs"],
)

rust_test(
    name = "test",
    deps = [":cargo_build_script_output_parser"],
)

rust_binary(
    name = "cargo_build_script_runner",
    srcs = ["bin.rs"],
    deps = [":cargo_build_script_output_parser"],
    visibility = ["//visibility:public"],
)