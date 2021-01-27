load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load("//worker:toolchain.bzl", "worker_toolchain")
load(":bootstrap.bzl", "rust_cargo_binary")
load("@bazel_skylib//rules:common_settings.bzl", "bool_flag")

package(default_visibility = ["//visibility:public"])

exports_files([
    "repositories.bzl",
])

bzl_library(
    name = "rules",
    srcs = glob(["**/*.bzl"]),
)

bool_flag(
    name = "use_worker",
    build_setting_default = False,
)

toolchain_type(name = "toolchain_type")

rust_cargo_binary(
    name = "rustc-worker",
    srcs = [
        "main.rs",
        "Cargo.toml",
        "Cargo.lock",
    ] + glob(["lib/*.rs"]),
    tags = ["manual"],
)

worker_toolchain(
    name = "worker_toolchain",
    enabled = ":use_worker",
    worker_binary = ":rustc-worker",
)

toolchain(
    name = "worker",
    toolchain = ":worker_toolchain",
    toolchain_type = ":toolchain_type",
)
