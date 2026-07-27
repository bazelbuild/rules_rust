"""# Legacy toolchains interface

This file re-exports the public toolchain rules from their dedicated bzl
files for backwards compatibility.
"""

load(
    "//rust/private:rust_analyzer.bzl",
    _current_rust_analyzer_toolchain = "current_rust_analyzer_toolchain",
)
load(
    "//rust/private:rustfmt.bzl",
    _current_rustfmt_toolchain = "current_rustfmt_toolchain",
)
load(
    ":rust_analyzer_toolchain.bzl",
    _rust_analyzer_toolchain = "rust_analyzer_toolchain",
)
load(
    ":rust_stdlib_filegroup.bzl",
    _rust_stdlib_filegroup = "rust_stdlib_filegroup",
)
load(
    ":rust_toolchain.bzl",
    _rust_toolchain = "rust_toolchain",
)
load(
    ":rustfmt_toolchain.bzl",
    _rustfmt_toolchain = "rustfmt_toolchain",
)

rust_toolchain = _rust_toolchain
rust_stdlib_filegroup = _rust_stdlib_filegroup
rust_analyzer_toolchain = _rust_analyzer_toolchain
current_rust_analyzer_toolchain = _current_rust_analyzer_toolchain
rustfmt_toolchain = _rustfmt_toolchain
current_rustfmt_toolchain = _current_rustfmt_toolchain
