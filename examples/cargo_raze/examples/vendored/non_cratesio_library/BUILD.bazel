load("@rules_rust//rust:rust.bzl", "rust_binary")

package(default_visibility = ["//visibility:public"])

rust_binary(
    name = "non_cratesio_library",
    srcs = ["src/main.rs"],
    deps = [
        "//vendored/non_cratesio_library/cargo:env_logger",
        "//vendored/non_cratesio_library/cargo:futures",
        "//vendored/non_cratesio_library/cargo:log",
    ],
)
