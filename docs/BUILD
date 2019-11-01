package(default_visibility = ["//visibility:private"])

load("@io_bazel_skydoc//stardoc:stardoc.bzl", "stardoc")

stardoc(
    name = "rust-docs",
    out = "index.md",
    input = ":all.bzl",
    symbol_names = [
        "rust_library",
        "rust_binary",
        "rust_benchmark",  # TODO(stardoc): no lint against absent symbols
        "rust_test",
        "rust_doc",
        "rust_doc_test",
        "rust_toolchain",
        "rust_proto_toolchain",
        "rust_proto_library",
        "rust_grpc_library",
        "rust_bindgen_toolchain",
        "rust_bindgen",
        "rust_bindgen_library",
    ],
    deps = [
        "@io_bazel_rules_rust//bindgen:rules",
        "@io_bazel_rules_rust//proto:rules",
        "@io_bazel_rules_rust//rust:rules",
    ],
)
