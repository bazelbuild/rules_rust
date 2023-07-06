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
    _rust_bindgen_dependencies = "rust_bindgen_dependencies",
    _rust_bindgen_register_toolchains = "rust_bindgen_register_toolchains",
)
load(
    "@rules_rust//cargo:defs.bzl",
    _cargo_bootstrap_repository = "cargo_bootstrap_repository",
    _cargo_build_script = "cargo_build_script",
    _cargo_dep_env = "cargo_dep_env",
    _cargo_env = "cargo_env",
)
load(
    "@rules_rust//crate_universe:docs.bzl",
    _crate = "crate",
    _crate_universe_dependencies = "crate_universe_dependencies",
    _crates_repository = "crates_repository",
    _crates_vendor = "crates_vendor",
)
load(
    "@rules_rust//proto/prost:defs.bzl",
    _rust_prost_library = "rust_prost_library",
    _rust_prost_toolchain = "rust_prost_toolchain",
)
load(
    "@rules_rust//proto/prost:repositories.bzl",
    _rust_prost_dependencies = "rust_prost_dependencies",
)
load(
    "@rules_rust//proto/protobuf:defs.bzl",
    _rust_grpc_library = "rust_grpc_library",
    _rust_proto_library = "rust_proto_library",
)
load(
    "@rules_rust//proto/protobuf:repositories.bzl",
    _rust_proto_protobuf_dependencies = "rust_proto_protobuf_dependencies",
    _rust_proto_protobuf_register_toolchains = "rust_proto_protobuf_register_toolchains",
)
load(
    "@rules_rust//proto/protobuf:toolchain.bzl",
    _rust_proto_toolchain = "rust_proto_toolchain",
)
load(
    "@rules_rust//proto/protobuf:transitive_repositories.bzl",
    _rust_proto_protobuf_transitive_repositories = "rust_proto_protobuf_transitive_repositories",
)
load(
    "@rules_rust//rust:defs.bzl",
    _capture_clippy_output = "capture_clippy_output",
    _error_format = "error_format",
    _extra_rustc_flag = "extra_rustc_flag",
    _extra_rustc_flags = "extra_rustc_flags",
    _rust_analyzer_aspect = "rust_analyzer_aspect",
    _rust_binary = "rust_binary",
    _rust_clippy = "rust_clippy",
    _rust_clippy_aspect = "rust_clippy_aspect",
    _rust_doc = "rust_doc",
    _rust_doc_test = "rust_doc_test",
    _rust_library = "rust_library",
    _rust_library_group = "rust_library_group",
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
    _rules_rust_dependencies = "rules_rust_dependencies",
    _rust_analyzer_toolchain_repository = "rust_analyzer_toolchain_repository",
    _rust_analyzer_toolchain_tools_repository = "rust_analyzer_toolchain_tools_repository",
    _rust_register_toolchains = "rust_register_toolchains",
    _rust_repositories = "rust_repositories",
    _rust_repository_set = "rust_repository_set",
    _rust_toolchain_repository = "rust_toolchain_repository",
    _rust_toolchain_repository_proxy = "rust_toolchain_repository_proxy",
    _rust_toolchain_tools_repository = "rust_toolchain_tools_repository",
    _rustfmt_toolchain_repository = "rustfmt_toolchain_repository",
    _rustfmt_toolchain_tools_repository = "rustfmt_toolchain_tools_repository",
    _toolchain_repository_proxy = "toolchain_repository_proxy",
)
load(
    "@rules_rust//rust:toolchain.bzl",
    _rust_analyzer_toolchain = "rust_analyzer_toolchain",
    _rust_stdlib_filegroup = "rust_stdlib_filegroup",
    _rust_toolchain = "rust_toolchain",
    _rustfmt_toolchain = "rustfmt_toolchain",
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
rust_library_group = _rust_library_group
rust_static_library = _rust_static_library
rust_shared_library = _rust_shared_library
rust_proc_macro = _rust_proc_macro
rust_test = _rust_test
rust_test_suite = _rust_test_suite
rust_doc = _rust_doc
rust_doc_test = _rust_doc_test

rust_prost_library = _rust_prost_library
rust_prost_toolchain = _rust_prost_toolchain
rust_grpc_library = _rust_grpc_library
rust_proto_library = _rust_proto_library

rust_bindgen = _rust_bindgen
rust_bindgen_dependencies = _rust_bindgen_dependencies
rust_bindgen_library = _rust_bindgen_library
rust_bindgen_register_toolchains = _rust_bindgen_register_toolchains
rust_bindgen_toolchain = _rust_bindgen_toolchain

rust_toolchain = _rust_toolchain
rust_proto_toolchain = _rust_proto_toolchain
rust_proto_protobuf_dependencies = _rust_proto_protobuf_dependencies
rust_proto_protobuf_register_toolchains = _rust_proto_protobuf_register_toolchains
rust_prost_dependencies = _rust_prost_dependencies
rust_stdlib_filegroup = _rust_stdlib_filegroup
rust_proto_protobuf_transitive_repositories = _rust_proto_protobuf_transitive_repositories
rust_prost_transitive_repositories = _rust_proto_protobuf_transitive_repositories

cargo_bootstrap_repository = _cargo_bootstrap_repository
cargo_build_script = _cargo_build_script
cargo_dep_env = _cargo_dep_env
cargo_env = _cargo_env

rust_wasm_bindgen = _rust_wasm_bindgen
rust_wasm_bindgen_dependencies = _rust_wasm_bindgen_dependencies
rust_wasm_bindgen_register_toolchains = _rust_wasm_bindgen_register_toolchains
rust_wasm_bindgen_toolchain = _rust_wasm_bindgen_toolchain

rules_rust_dependencies = _rules_rust_dependencies
rust_register_toolchains = _rust_register_toolchains
rust_repositories = _rust_repositories
rust_repository_set = _rust_repository_set
rust_toolchain_repository = _rust_toolchain_repository
rust_toolchain_repository_proxy = _rust_toolchain_repository_proxy
rust_toolchain_tools_repository = _rust_toolchain_tools_repository
rustfmt_toolchain_tools_repository = _rustfmt_toolchain_tools_repository
rustfmt_toolchain_repository = _rustfmt_toolchain_repository
rust_analyzer_toolchain_repository = _rust_analyzer_toolchain_repository
rust_analyzer_toolchain_tools_repository = _rust_analyzer_toolchain_tools_repository
toolchain_repository_proxy = _toolchain_repository_proxy

rust_clippy = _rust_clippy
rust_clippy_aspect = _rust_clippy_aspect
rust_analyzer_aspect = _rust_analyzer_aspect
rust_analyzer_toolchain = _rust_analyzer_toolchain

crate = _crate
crates_repository = _crates_repository
crates_vendor = _crates_vendor
crate_universe_dependencies = _crate_universe_dependencies

rustfmt_aspect = _rustfmt_aspect
rustfmt_test = _rustfmt_test
rustfmt_toolchain = _rustfmt_toolchain

error_format = _error_format
extra_rustc_flag = _extra_rustc_flag
extra_rustc_flags = _extra_rustc_flags
incompatible_flag = _incompatible_flag
capture_clippy_output = _capture_clippy_output

CrateInfo = _CrateInfo
DepInfo = _DepInfo
StdLibInfo = _StdLibInfo
