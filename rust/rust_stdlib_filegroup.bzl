"""# Rust Stdlib Filegroup

Public entry point for the [rust_stdlib_filegroup](#rust_stdlib_filegroup) rule.
Implementation lives in `//rust/private:toolchain.bzl`.
"""

load(
    "//rust/private:toolchain.bzl",
    _rust_stdlib_filegroup = "rust_stdlib_filegroup",
)

rust_stdlib_filegroup = _rust_stdlib_filegroup
