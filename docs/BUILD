package(default_visibility = ["//visibility:private"])

load("@io_bazel_skydoc//stardoc:stardoc.bzl", "stardoc")

stardoc(
    name = "rust-docs",
    out = "index.md",
    input = ":all.bzl",
    deps = [
        "@io_bazel_rules_rust//proto:rules",
        "@io_bazel_rules_rust//rust:rules",
    ],
)
