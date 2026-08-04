"""# Rustfmt Toolchain"""

load(
    "//rust/private:rustfmt.bzl",
    _rustfmt_toolchain = "rustfmt_toolchain",
)

rustfmt_toolchain = _rustfmt_toolchain
