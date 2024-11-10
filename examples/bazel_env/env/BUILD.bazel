load("@bazel_env.bzl", "bazel_env")

package(default_visibility = ["//visibility:public"])

bazel_env(
    name = "env",
    tools = {
        "cargo": "@rules_rust//tools/upstream_wrapper:cargo",
        "cargo-clippy": "@rules_rust//tools/upstream_wrapper:cargo_clippy",
        "rustc": "@rules_rust//tools/upstream_wrapper:rustc",
        "rustfmt": "@rules_rust//tools/upstream_wrapper:rustfmt",
    },
)
