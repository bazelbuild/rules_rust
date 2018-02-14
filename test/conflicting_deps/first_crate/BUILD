package(default_visibility = ["//visibility:public"])

load(
    "//rust:rust.bzl",
    "rust_library",
)

rust_library(
    name = "example_name_conflict",
    srcs = ["src/lib.rs"],
    deps = [
        "//test/conflicting_deps/first_crate/second_crate:example_name_conflict"
    ],
)

