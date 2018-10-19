load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_doc_test",
    "rust_library",
    "rust_test",
)

rust_library(
    name = "runfiles",
    srcs = ["runfiles.rs"],
    visibility = ["//visibility:public"],
)

rust_test(
    name = "runfiles_test",
    data = ["data/sample.txt"],
    deps = [":runfiles"],
)

rust_doc_test(
    name = "runfiles_doc_test",
    dep = ":runfiles",
)
