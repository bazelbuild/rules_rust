load("@rules_rust//rust:rust.bzl", "rust_binary")
load("@rules_rust//proto/prostgen:prostgen.bzl", "TONIC_COMPILE_DEPS")


rust_binary(
    name = "greeter_server",
    srcs = ["greeter_server.rs"],
    visibility = ["//:__subpackages__"],
    deps = [
        "//prostgen/helloworld:helloworld_proto",
        # "//prostgen/raze:tokio",
    ] + TONIC_COMPILE_DEPS,
    edition = "2018",
)
