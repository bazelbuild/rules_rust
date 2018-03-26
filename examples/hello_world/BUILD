package(default_visibility = ["//visibility:public"])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_binary",
    "rust_doc",
    "rust_doc_test",
)

genrule(
    name = "message",
    srcs = [],
    outs = ["message.string"],
    cmd = "echo 'hi from genrule' > \"$@\"",
)

rust_binary(
    name = "hello_world",
    srcs = ["src/main.rs"],
    data = [":message"],
    deps = ["@examples//hello_lib"],
)

rust_doc(
    name = "hello_world_doc",
    dep = ":hello_world",
)

rust_doc_test(
    name = "hello_world_doc_test",
    dep = ":hello_world",
)
