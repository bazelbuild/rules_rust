"""# clippy_toolchain.bzl"""

load(
    "//rust/private:clippy_toolchain.bzl",
    _clippy_toolchain = "clippy_toolchain",
    _clippy_toolchain_alias = "clippy_toolchain_alias",
    _find_clippy = "find_clippy",
)

clippy_toolchain = _clippy_toolchain
clippy_toolchain_alias = _clippy_toolchain_alias
find_clippy = _find_clippy
