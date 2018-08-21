package(default_visibility = ["//visibility:public"])

load(
    "//rust:rust.bzl",
    "rust_library",
)

rust_library(
    name = "example_name_conflict",
    srcs = ["lib.rs"],
    deps = [
        "//test/conflicting_deps/second_crate:example_name_conflict",
    ],
)
