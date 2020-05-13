package(default_visibility = ["//visibility:public"])

load(
    "//rust:rust.bzl",
    "rust_binary",
    "rust_library",
    "rust_test",
)

rust_library(
    name = "test_build_script",
    srcs = ["src/lib.rs"],
    build_script_output = ":buildrs_output.txt",
)

rust_binary(
    name = "test_build_script_bin",
    srcs = ["src/main.rs"],
    build_script_output = ":buildrs_output.txt",
)

rust_test(
    name = "test_build_script_test",
    crate = ":test_build_script",
    build_script_output = ":buildrs_output.txt",
)
