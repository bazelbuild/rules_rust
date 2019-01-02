package(default_visibility = ["//visibility:public"])

load(
    "//rust:rust.bzl",
    "rust_test",
)

rust_test(
    name = "conflicting_deps_test",
    srcs = ["tests/manifest_dir.rs"],
    data = ["src/manifest_dir_file.txt"],
)
