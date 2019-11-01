package(default_visibility = ["//visibility:public"])

load(
    "//rust:rust.bzl",
    "rust_library",
    "rust_test",
)

rust_library(
    name = "inline",
    srcs = ["src/lib.rs"],
    edition = "2018",
)

rust_test(
    name = "inline_test",
    srcs = ["src/extra.rs"],
    crate = ":inline",
    deps = ["//test/inline_test_with_deps/dep"],
)
