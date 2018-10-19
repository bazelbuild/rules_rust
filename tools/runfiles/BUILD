load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_library",
    "rust_doc_test",
)

rust_library(
    name = "runfiles",
    srcs = ["runfiles.rs"],
    visibility = ["//visibility:public"],
)

rust_doc_test(
    name = "runfiles_doc_test",
    dep = ":runfiles",
)

