"""This module provides a single place for all aspects, rules, and macros that are meant
to have stardoc generated documentation.
"""

load(
    "@io_bazel_rules_rust//bindgen:bindgen.bzl",
    _rust_bindgen = "rust_bindgen",
    _rust_bindgen_library = "rust_bindgen_library",
    _rust_bindgen_toolchain = "rust_bindgen_toolchain",
)
load(
    "@io_bazel_rules_rust//cargo:cargo_build_script.bzl",
    _cargo_build_script = "cargo_build_script",
)
load(
    "@io_bazel_rules_rust//proto:proto.bzl",
    _rust_grpc_library = "rust_grpc_library",
    _rust_proto_library = "rust_proto_library",
)
load(
    "@io_bazel_rules_rust//proto:toolchain.bzl",
    _rust_proto_toolchain = "rust_proto_toolchain",
)
load(
    "@io_bazel_rules_rust//rust:repositories.bzl",
    _rust_repositories = "rust_repositories",
    _rust_repository_set = "rust_repository_set",
    _rust_toolchain_repository = "rust_toolchain_repository",
    _rust_toolchain_repository_proxy = "rust_toolchain_repository_proxy",
)
load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    _rust_benchmark = "rust_benchmark",
    _rust_binary = "rust_binary",
    _rust_doc = "rust_doc",
    _rust_doc_test = "rust_doc_test",
    _rust_library = "rust_library",
    _rust_test = "rust_test",
)
load(
    "@io_bazel_rules_rust//rust:toolchain.bzl",
    _rust_toolchain = "rust_toolchain",
)
# This cannot be included due to https://github.com/google/cargo-raze/issues/285
# load(
#     "@io_bazel_rules_rust//wasm_bindgen:repositories.bzl",
#     _rust_wasm_bindgen_repositories = "rust_wasm_bindgen_repositories",
# )
load(
    "@io_bazel_rules_rust//wasm_bindgen:wasm_bindgen.bzl",
    _rust_wasm_bindgen = "rust_wasm_bindgen",
    _rust_wasm_bindgen_toolchain = "rust_wasm_bindgen_toolchain",
)

rust_library = _rust_library
rust_binary = _rust_binary
rust_test = _rust_test
rust_doc = _rust_doc
rust_doc_test = _rust_doc_test

rust_benchmark = _rust_benchmark
rust_proto_library = _rust_proto_library
rust_grpc_library = _rust_grpc_library

rust_bindgen_toolchain = _rust_bindgen_toolchain
rust_bindgen = _rust_bindgen
rust_bindgen_library = _rust_bindgen_library

rust_toolchain = _rust_toolchain
rust_proto_toolchain = _rust_proto_toolchain

cargo_build_script = _cargo_build_script

rust_wasm_bindgen = _rust_wasm_bindgen
rust_wasm_bindgen_toolchain = _rust_wasm_bindgen_toolchain
# This cannot be included due to https://github.com/google/cargo-raze/issues/285
# rust_wasm_bindgen_repositories = _rust_wasm_bindgen_repositories

rust_repositories = _rust_repositories
rust_repository_set = _rust_repository_set
rust_toolchain_repository = _rust_toolchain_repository
rust_toolchain_repository_proxy = _rust_toolchain_repository_proxy
