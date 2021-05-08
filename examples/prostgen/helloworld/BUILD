load("@rules_proto//proto:defs.bzl", "proto_library")
load("@rules_rust//proto/prostgen:prostgen.bzl", "tonic_library")
load("@rules_rust//rust:rust.bzl", "rust_test")

proto_library(
    name = "helloworld",
    srcs = ["helloworld.proto"],
    deps = ["//prostgen:common"],
)

tonic_library(
    name = "helloworld_proto",
    visibility = ["//:__subpackages__"],
    deps = [":helloworld"],
)

rust_test(
    name = "helloworld_test",
    srcs = ["helloworld_test.rs"],
    data = [
        "//prostgen/helloworld/greeter_client",
        "//prostgen/helloworld/greeter_server",
    ],
    deps = ["@rules_rust//tools/runfiles"],
)
