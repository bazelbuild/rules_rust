load("@rules_rust//rust:rust.bzl", "rust_binary")

rust_binary(
    name = "greeter_client",
    srcs = ["greeter_client.rs"],
    edition = "2018",
    visibility = ["//:__subpackages__"],
    deps = [
        "//prostgen/helloworld:helloworld_proto",
        "//prostgen/raze:tokio",
        "//prostgen/raze:tonic",
    ],
)
