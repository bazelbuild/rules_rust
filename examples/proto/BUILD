load("@rules_proto//proto:defs.bzl", "proto_library")
load("@io_bazel_rules_rust//proto:proto.bzl", "rust_proto_library")
load("@io_bazel_rules_rust//rust:rust.bzl", "rust_library")
load("@io_bazel_rules_rust//rust:rust.bzl", "rust_binary")

package(default_visibility = ["//proto:__subpackages__"])

proto_library(
    name = "common",
    srcs = ["common.proto"],
)

rust_proto_library(
    name = "common_proto_rust",
    deps = [":common"],
)

rust_library(
    name = "common_lib",
    srcs = ["lib.rs"],
    deps = [":common_proto_rust"],
)

rust_binary(
    name = "common_bin",
    srcs = ["main.rs"],
    deps = [
        ":common_lib",
        ":common_proto_rust",
    ],
)
