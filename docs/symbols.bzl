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
)
load(
    "@rules_rust//rust:toolchain.bzl",
    _rust_cargo_toolchain = "rust_cargo_toolchain",
    _rust_clippy_toolchain = "rust_clippy_toolchain",
    _rust_exec_toolchain = "rust_exec_toolchain",
    _rust_rustfmt_toolchain = "rust_rustfmt_toolchain",
    _rust_stdlib_filegroup = "rust_stdlib_filegroup",
    _rust_target_toolchain = "rust_target_toolchain",
    _rust_toolchain = "rust_toolchain",
)
load(
    "@rules_rust//rust:toolchain_repositories.bzl",
    _rust_cargo_repository = "rust_cargo_repository",
    _rust_clippy_repository = "rust_clippy_repository",
    _rust_exec_toolchain_repository = "rust_exec_toolchain_repository",
    _rust_rustc_repository = "rust_rustc_repository",
    _rust_rustfmt_repository = "rust_rustfmt_repository",
    _rust_stdlib_repository = "rust_stdlib_repository",
    _rust_target_toolchain_repository = "rust_target_toolchain_repository",
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
    _fail_when_enabled = "fail_when_enabled",
    _incompatible_flag = "incompatible_flag",
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

rust_proto_library = _rust_proto_library
rust_grpc_library = _rust_grpc_library

rust_bindgen_toolchain = _rust_bindgen_toolchain
rust_bindgen = _rust_bindgen
rust_bindgen_library = _rust_bindgen_library
rust_bindgen_repositories = _rust_bindgen_repositories

rust_toolchain = _rust_toolchain
rust_exec_toolchain = _rust_exec_toolchain
rust_target_toolchain = _rust_target_toolchain
rust_cargo_toolchain = _rust_cargo_toolchain
rust_clippy_toolchain = _rust_clippy_toolchain
rust_rustfmt_toolchain = _rust_rustfmt_toolchain

rust_proto_toolchain = _rust_proto_toolchain
rust_proto_repositories = _rust_proto_repositories
rust_stdlib_filegroup = _rust_stdlib_filegroup
rust_proto_transitive_repositories = _rust_proto_transitive_repositories

cargo_build_script = _cargo_build_script
cargo_bootstrap_repository = _cargo_bootstrap_repository
cargo_env = _cargo_env

rust_wasm_bindgen = _rust_wasm_bindgen
rust_wasm_bindgen_toolchain = _rust_wasm_bindgen_toolchain
rust_wasm_bindgen_repositories = _rust_wasm_bindgen_repositories

rust_repositories = _rust_repositories
rust_exec_toolchain_repository = _rust_exec_toolchain_repository
rust_target_toolchain_repository = _rust_target_toolchain_repository
rust_rustc_repository = _rust_rustc_repository
rust_clippy_repository = _rust_clippy_repository
rust_cargo_repository = _rust_cargo_repository
rust_rustfmt_repository = _rust_rustfmt_repository
rust_repository_set = _rust_repository_set
rust_stdlib_repository = _rust_stdlib_repository

rust_clippy = _rust_clippy
rust_clippy_aspect = _rust_clippy_aspect
rust_analyzer = _rust_analyzer
rust_analyzer_aspect = _rust_analyzer_aspect

crate_universe = _crate_universe
crate = _crate

rustfmt_aspect = _rustfmt_aspect
rustfmt_test = _rustfmt_test

error_format = _error_format
extra_rustc_flags = _extra_rustc_flags
incompatible_flag = _incompatible_flag
fail_when_enabled = _fail_when_enabled
capture_clippy_output = _capture_clippy_output

CrateInfo = _CrateInfo
DepInfo = _DepInfo
StdLibInfo = _StdLibInfo
