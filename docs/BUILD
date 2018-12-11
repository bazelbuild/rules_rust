package(default_visibility = ["//visibility:private"])

load("@io_bazel_skydoc//stardoc:stardoc.bzl", "stardoc")

stardoc(
    name = "rust-docs",
    out = "toolchain.md",
    # TODO: Blocked up lack of upstream bzl_library...
    # input = "@io_bazel_rules_rust//rust:rust.bzl",
    # So lets use toolchain.bzl which has no external dependencies.
    input = "@io_bazel_rules_rust//rust:toolchain.bzl",
    deps = [
        "@io_bazel_rules_rust//rust:rules",
    ],
)
