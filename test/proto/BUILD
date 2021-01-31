load("@rules_proto//proto:defs.bzl", "proto_library")
load("@rules_rust//proto:proto.bzl", "rust_proto_library")

proto_library(
    name = "a_proto",
    srcs = ["a.proto"],
    strip_import_prefix = "",
)

proto_library(
    name = "b_proto",
    srcs = ["b.proto"],
    strip_import_prefix = "",
    deps = [":a_proto"],
)

rust_proto_library(
    name = "b_rust",
    deps = [":b_proto"],
)
