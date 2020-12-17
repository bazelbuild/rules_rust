# Code Generation for protobuf using the prost library

load("//rust:rust.bzl", "rust_binary", "rust_doc", "rust_library", "rust_test")

package(default_visibility = ["//visibility:private"])

exports_files(["rules.bzl"])

rust_library(
    name = "prostgen_lib",
    srcs = [
        "extern_path.rs",
        "lib.rs",
        "module.rs",
    ],
    deps = [
        "//proto/prostgen/raze:anyhow",
        "//proto/prostgen/raze:heck",
        "//proto/prostgen/raze:prost",
        "//proto/prostgen/raze:prost_build",
        "//proto/prostgen/raze:prost_types",
        "//proto/prostgen/raze:structopt",
        "//proto/prostgen/raze:thiserror",
        "//proto/prostgen/raze:tonic_build",
    ],
)

rust_binary(
    name = "prostgen",
    srcs = ["main.rs"],
    visibility = ["//visibility:public"],
    deps = [
        ":prostgen_lib",
        "//proto/prostgen/raze:anyhow",
        "//proto/prostgen/raze:structopt",
    ],
)

rust_doc(
    name = "prostgen_doc",
    dep = ":prostgen_lib",
)

rust_test(
    name = "prostgen_test",
    crate = ":prostgen_lib",
)
