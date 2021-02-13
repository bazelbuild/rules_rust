load("@rules_rust//rust:rust.bzl", "rust_binary")

package(default_visibility = ["//visibility:public"])

rust_binary(
    name = "hello_cargo_library",
    srcs = ["src/main.rs"],
    deps = [
        "//vendored/hello_cargo_library/cargo:fern",
        "//vendored/hello_cargo_library/cargo:log",
    ],
)
