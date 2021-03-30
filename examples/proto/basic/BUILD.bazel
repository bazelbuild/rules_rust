load("@rules_rust//proto:proto.bzl", "rust_proto_library")
load("@rules_rust//rust:rust.bzl", "rust_binary", "rust_library")

package(default_visibility = ["//proto:__subpackages__"])

rust_proto_library(
    name = "common_proto_rust",
    deps = ["//proto:common"],
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
