"""This module provides a single place for all aspects, rules, and macros that are meant
to have stardoc generated documentation.
"""

load(
    "@rules_rust//bindgen:bindgen.bzl",
    _rust_bindgen = "rust_bindgen",
    _rust_bindgen_library = "rust_bindgen_library",
    _rust_bindgen_toolchain = "rust_bindgen_toolchain",
)
load(
    "@rules_rust//bindgen:repositories.bzl",
    _rust_bindgen_repositories = "rust_bindgen_repositories",
)
load(
    "@rules_rust//cargo:cargo_build_script.bzl",
    _cargo_build_script = "cargo_build_script",
)
load(
    "@rules_rust//crate_universe:defs.bzl",
    _crate = "crate",
    _crate_universe = "crate_universe",
)
load(
    "@rules_rust//proto:proto.bzl",
    _rust_grpc_library = "rust_grpc_library",
    _rust_proto_library = "rust_proto_library",
)
load(
    "@rules_rust//proto:repositories.bzl",
    _rust_proto_repositories = "rust_proto_repositories",
)
load(
    "@rules_rust//proto:toolchain.bzl",
    _rust_proto_toolchain = "rust_proto_toolchain",
)
load(
    "@rules_rust//rust:defs.bzl",
    _rust_analyzer = "rust_analyzer",
    _rust_analyzer_aspect = "rust_analyzer_aspect",
    _rust_benchmark = "rust_benchmark",
    _rust_binary = "rust_binary",
    _rust_clippy = "rust_clippy",
    _rust_clippy_aspect = "rust_clippy_aspect",
    _rust_doc = "rust_doc",
    _rust_doc_test = "rust_doc_test",
    _rust_library = "rust_library",
    _rust_proc_macro = "rust_proc_macro",
    _rust_shared_library = "rust_shared_library",
    _rust_static_library = "rust_static_library",
    _rust_test = "rust_test",
    _rust_test_suite = "rust_test_suite",
    _rustfmt_aspect = "rustfmt_aspect",
    _rustfmt_test = "rustfmt_test",
)
load(
    "@rules_rust//rust:repositories.bzl",
    _rust_repositories = "rust_repositories",
    _rust_repository_set = "rust_repository_set",
    _rust_toolchain_repository = "rust_toolchain_repository",
    _rust_toolchain_repository_proxy = "rust_toolchain_repository_proxy",
)
load(
    "@rules_rust//rust:toolchain.bzl",
    _rust_toolchain = "rust_toolchain",
)
load(
    "@rules_rust//wasm_bindgen:repositories.bzl",
    _rust_wasm_bindgen_repositories = "rust_wasm_bindgen_repositories",
)
load(
    "@rules_rust//wasm_bindgen:wasm_bindgen.bzl",
    _rust_wasm_bindgen = "rust_wasm_bindgen",
    _rust_wasm_bindgen_toolchain = "rust_wasm_bindgen_toolchain",
)

rust_binary = _rust_binary
rust_library = _rust_library
rust_static_library = _rust_static_library
rust_shared_library = _rust_shared_library
rust_proc_macro = _rust_proc_macro
rust_test = _rust_test
rust_test_suite = _rust_test_suite
rust_doc = _rust_doc
rust_doc_test = _rust_doc_test

rust_benchmark = _rust_benchmark
rust_proto_library = _rust_proto_library
rust_grpc_library = _rust_grpc_library

rust_bindgen_toolchain = _rust_bindgen_toolchain
rust_bindgen = _rust_bindgen
rust_bindgen_library = _rust_bindgen_library
rust_bindgen_repositories = _rust_bindgen_repositories

rust_toolchain = _rust_toolchain
rust_proto_toolchain = _rust_proto_toolchain
rust_proto_repositories = _rust_proto_repositories

cargo_build_script = _cargo_build_script

rust_wasm_bindgen = _rust_wasm_bindgen
rust_wasm_bindgen_toolchain = _rust_wasm_bindgen_toolchain
rust_wasm_bindgen_repositories = _rust_wasm_bindgen_repositories

rust_repositories = _rust_repositories
rust_repository_set = _rust_repository_set
rust_toolchain_repository = _rust_toolchain_repository
rust_toolchain_repository_proxy = _rust_toolchain_repository_proxy

rust_clippy = _rust_clippy
rust_clippy_aspect = _rust_clippy_aspect
rust_analyzer = _rust_analyzer
rust_analyzer_aspect = _rust_analyzer_aspect

crate_universe = _crate_universe
crate = _crate

rustfmt_aspect = _rustfmt_aspect
rustfmt_test = _rustfmt_test
