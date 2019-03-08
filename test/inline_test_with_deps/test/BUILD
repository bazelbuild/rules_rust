package(default_visibility = ["//visibility:public"])

load(
    "//rust:rust.bzl",
    "rust_library",
    "rust_test",
)

rust_library(
    name = "inline",
    edition = "2018",
    srcs = ["src/lib.rs"],
)

rust_test(
    name = "inline_test",
    crate = ":inline",
    deps = ["//test/inline_test_with_deps/dep"],
)
