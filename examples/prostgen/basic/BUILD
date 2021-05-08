load("@rules_rust//proto/prostgen:prostgen.bzl", "prost_library")
load("@rules_rust//rust:rust.bzl", "rust_binary", "rust_library")

package(default_visibility = ["//:__subpackages__"])

prost_library(
    name = "common_proto_rust",
    deps = ["//prostgen:common"],
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
