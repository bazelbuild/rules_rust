"""# Rust Toolchain

Public entry point for the [rust_toolchain](#rust_toolchain) rule.
Implementation lives in `//rust/private:toolchain.bzl`.
"""

load(
    "//rust/private:toolchain.bzl",
    _rust_toolchain = "rust_toolchain",
)

rust_toolchain = _rust_toolchain
