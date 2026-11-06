"""# rustdoc_toolchain.bzl"""

load(
    "//rust/private:rustdoc_toolchain.bzl",
    _find_rustdoc = "find_rustdoc",
    _rustdoc_toolchain = "rustdoc_toolchain",
    _rustdoc_toolchain_alias = "rustdoc_toolchain_alias",
)

rustdoc_toolchain = _rustdoc_toolchain
rustdoc_toolchain_alias = _rustdoc_toolchain_alias
find_rustdoc = _find_rustdoc
