load("@rules_rust//rust:defs.bzl", "rust_binary")
load("@rules_rust//cargo:defs.bzl", "cargo_build_script")

package(
    default_visibility = ["//visibility:public"],
)

cargo_build_script(
    name = "build_script",
    srcs = ["build.rs"],
    data = ["data.txt"],
    deps = [
        "@rules_rust//tools/runfiles",
    ],
)

rust_binary(
    name = "reproduce_bin",
    srcs = ["main.rs"],
    deps = [":build_script"],
)
