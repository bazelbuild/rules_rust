"""# rust_toolchain.bzl"""

load(
    "//rust/private:toolchain.bzl",
    _rust_toolchain = "rust_toolchain",
)

rust_toolchain = _rust_toolchain
