load("@io_bazel_rules_rust//rust:rust.bzl", "rust_binary")
load("@io_bazel_rules_rust//proto:toolchain.bzl", "GRPC_COMPILE_DEPS")

rust_binary(
    name = "greeter_client",
    srcs = ["greeter_client.rs"],
    visibility = ["//proto/helloworld:__subpackages__"],
    deps = [
        "//proto/helloworld:helloworld_proto",
    ] + GRPC_COMPILE_DEPS,
)
