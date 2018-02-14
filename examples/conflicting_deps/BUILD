package(default_visibility = ["//visibility:public"])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_library",
    "rust_test",
)

rust_library(
    name = "conflicting_deps",
    srcs = ["src/lib.rs"],
    deps = [
        "@examples//conflicting_deps/first_crate:example_name_conflict"
    ],
)

rust_test(
    name = "conflicting_deps_test",
    deps = [
        ":conflicting_deps",
    ],
)
