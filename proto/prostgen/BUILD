# Code Generation for protobuf using the prost library

load("//rust:rust.bzl", "rust_binary", "rust_doc", "rust_library", "rust_test")

package(default_visibility = ["//visibility:private"])

exports_files(["prostgen.bzl"])

rust_library(
    name = "prostgen_lib",
    srcs = [
        "extern_path.rs",
        "lib.rs",
        "module.rs",
    ],
    edition = "2018",
    deps = [
        "@rules_rust//proto/prostgen/raze/cargo:anyhow",
        "@rules_rust//proto/prostgen/raze/cargo:heck",
        "@rules_rust//proto/prostgen/raze/cargo:prost",
        "@rules_rust//proto/prostgen/raze/cargo:prost_build",
        "@rules_rust//proto/prostgen/raze/cargo:prost_types",
        "@rules_rust//proto/prostgen/raze/cargo:structopt",
        "@rules_rust//proto/prostgen/raze/cargo:thiserror",
        "@rules_rust//proto/prostgen/raze/cargo:tonic_build",
    ],
)

rust_binary(
    name = "prostgen",
    srcs = ["main.rs"],
    edition = "2018",
    visibility = ["//visibility:public"],
    deps = [
        ":prostgen_lib",
        "@rules_rust//proto/prostgen/raze/cargo:anyhow",
        "@rules_rust//proto/prostgen/raze/cargo:structopt",
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
