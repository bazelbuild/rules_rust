load("@io_bazel_rules_rust//proto:proto.bzl", "rust_proto_library")

proto_library(
    name = "a_proto",
    srcs = ["a.proto"],
    strip_import_prefix = "/test/proto",
)

proto_library(
    name = "b_proto",
    srcs = ["b.proto"],
    deps = [":a_proto"],
    strip_import_prefix = "/test/proto",
)

rust_proto_library(
    name = "b_rust",
    deps = [":b_proto"],
)
