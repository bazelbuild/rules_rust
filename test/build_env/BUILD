package(default_visibility = ["//visibility:public"])

load(
    "//rust:rust.bzl",
    "rust_test",
)

rust_test(
    name = "environment_variable_test",
    srcs = ["tests/manifest_dir.rs"],
    data = ["src/manifest_dir_file.txt"],

    rustc_env = [
        "ARBITRARY_ENV1=Value1",
        "ARBITRARY_ENV2=Value2",
    ],
)
