load("@rules_rust//proto:toolchain.bzl", "GRPC_COMPILE_DEPS")
load("@rules_rust//rust:rust.bzl", "rust_binary")

rust_binary(
    name = "greeter_client",
    srcs = ["greeter_client.rs"],
    visibility = ["//proto/helloworld:__subpackages__"],
    deps = [
        "//proto/helloworld:helloworld_proto",
    ] + GRPC_COMPILE_DEPS,
)
