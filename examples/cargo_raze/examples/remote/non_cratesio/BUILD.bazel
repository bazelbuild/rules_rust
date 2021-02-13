load("@rules_rust//rust:rust.bzl", "rust_binary")

package(default_visibility = ["//visibility:public"])

rust_binary(
    name = "non_cratesio_remote",
    srcs = ["src/main.rs"],
    deps = [
        "//remote/non_cratesio/cargo:env_logger",
        "//remote/non_cratesio/cargo:log",
        "//remote/non_cratesio/cargo:rand",
    ],
)
