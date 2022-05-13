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
    "@rules_rust//cargo:defs.bzl",
    _cargo_bootstrap_repository = "cargo_bootstrap_repository",
    _cargo_build_script = "cargo_build_script",
    _cargo_env = "cargo_env",
)
load(
    "@rules_rust//crate_universe:defs.bzl",
    _crate = "crate",
    _crates_repository = "crates_repository",
    _crates_vendor = "crates_vendor",
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
    "@rules_rust//proto:transitive_repositories.bzl",
    _rust_proto_transitive_repositories = "rust_proto_transitive_repositories",
)
load(
    "@rules_rust//rust:defs.bzl",
    _capture_clippy_output = "capture_clippy_output",
    _error_format = "error_format",
    _extra_rustc_flags = "extra_rustc_flags",
    _rust_analyzer = "rust_analyzer",
    _rust_analyzer_aspect = "rust_analyzer_aspect",
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
    _rust_stdlib_filegroup = "rust_stdlib_filegroup",
    _rust_toolchain = "rust_toolchain",
)

# buildifier: disable=bzl-visibility
load(
    "@rules_rust//rust/private:providers.bzl",
    _CrateInfo = "CrateInfo",
    _DepInfo = "DepInfo",
    _StdLibInfo = "StdLibInfo",
)
load(
    "@rules_rust//rust/settings:incompatible.bzl",
    _incompatible_flag = "incompatible_flag",
)
load(
    "@rules_rust//wasm_bindgen:repositories.bzl",
    _rust_wasm_bindgen_dependencies = "rust_wasm_bindgen_dependencies",
    _rust_wasm_bindgen_register_toolchains = "rust_wasm_bindgen_register_toolchains",
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

rust_proto_library = _rust_proto_library
rust_grpc_library = _rust_grpc_library

rust_bindgen_toolchain = _rust_bindgen_toolchain
rust_bindgen = _rust_bindgen
rust_bindgen_library = _rust_bindgen_library
rust_bindgen_repositories = _rust_bindgen_repositories

rust_toolchain = _rust_toolchain
rust_proto_toolchain = _rust_proto_toolchain
rust_proto_repositories = _rust_proto_repositories
rust_stdlib_filegroup = _rust_stdlib_filegroup
rust_proto_transitive_repositories = _rust_proto_transitive_repositories

cargo_build_script = _cargo_build_script
cargo_bootstrap_repository = _cargo_bootstrap_repository
cargo_env = _cargo_env

rust_wasm_bindgen = _rust_wasm_bindgen
rust_wasm_bindgen_dependencies = _rust_wasm_bindgen_dependencies
rust_wasm_bindgen_register_toolchains = _rust_wasm_bindgen_register_toolchains
rust_wasm_bindgen_toolchain = _rust_wasm_bindgen_toolchain

rust_repositories = _rust_repositories
rust_repository_set = _rust_repository_set
rust_toolchain_repository = _rust_toolchain_repository
rust_toolchain_repository_proxy = _rust_toolchain_repository_proxy

rust_clippy = _rust_clippy
rust_clippy_aspect = _rust_clippy_aspect
rust_analyzer = _rust_analyzer
rust_analyzer_aspect = _rust_analyzer_aspect

crate = _crate
crates_repository = _crates_repository
crates_vendor = _crates_vendor

rustfmt_aspect = _rustfmt_aspect
rustfmt_test = _rustfmt_test

error_format = _error_format
extra_rustc_flags = _extra_rustc_flags
incompatible_flag = _incompatible_flag
capture_clippy_output = _capture_clippy_output

CrateInfo = _CrateInfo
DepInfo = _DepInfo
StdLibInfo = _StdLibInfo
