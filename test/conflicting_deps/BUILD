package(default_visibility = ["//visibility:public"])

load(
    "//rust:rust.bzl",
    "rust_library",
    "rust_test",
)

rust_library(
    name = "conflicting_deps",
    srcs = ["lib.rs"],
    deps = [
        "//test/conflicting_deps/first_crate:example_name_conflict",
    ],
)

rust_test(
    name = "conflicting_deps_test",
    crate = ":conflicting_deps",
)
