load("@rules_proto//proto:defs.bzl", "proto_library")
load("@rules_rust//proto:proto.bzl", "rust_grpc_library")
load("@rules_rust//rust:rust.bzl", "rust_test")

proto_library(
    name = "helloworld",
    srcs = ["helloworld.proto"],
    deps = ["//proto:common"],
)

rust_grpc_library(
    name = "helloworld_proto",
    visibility = ["//proto/helloworld:__subpackages__"],
    deps = [":helloworld"],
)

rust_test(
    name = "helloworld_test",
    srcs = ["helloworld_test.rs"],
    data = [
        "//proto/helloworld/greeter_client",
        "//proto/helloworld/greeter_server",
    ],
    deps = ["@rules_rust//tools/runfiles"],
)
