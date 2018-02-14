package(default_visibility = ["//visibility:public"])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_library",
)

rust_library(
    name = "example_name_conflict",
    srcs = ["src/lib.rs"],
    deps = [
        "@examples//conflicting_deps/first_crate/second_crate:example_name_conflict"
    ],
)

