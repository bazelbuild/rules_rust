load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load("//rust:rust.bzl", "rust_binary")
load(":toolchain.bzl", "rust_proto_toolchain")

package(default_visibility = ["//visibility:public"])

alias(
    name = "protoc_gen_rust",
    actual = "//proto/raze:cargo_bin_protoc_gen_rust",
)

alias(
    name = "protoc_gen_rust_grpc",
    actual = "//proto/raze:cargo_bin_protoc_gen_rust_grpc",
)

toolchain_type(name = "toolchain")

rust_binary(
    name = "optional_output_wrapper",
    srcs = ["optional_output_wrapper.rs"],
    visibility = ["//visibility:public"],
)

toolchain(
    name = "default-proto-toolchain",
    toolchain = ":default-proto-toolchain-impl",
    toolchain_type = "//proto:toolchain",
)

rust_proto_toolchain(name = "default-proto-toolchain-impl")

bzl_library(
    name = "rules",
    srcs = glob(["**/*.bzl"]) + ["//proto/raze:crates.bzl"],
)
