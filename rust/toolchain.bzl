"""# Legacy toolchains interface

This file re-exports the public toolchain rules from their dedicated bzl
files for backwards compatibility.
"""

load(
    "//rust/private:rust_analyzer.bzl",
    "rust_analyzer_toolchain_alias",
)
load(
    "//rust/private:rustfmt.bzl",
    "rustfmt_toolchain_alias",
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
rustfmt_toolchain = _rustfmt_toolchain

def current_rust_analyzer_toolchain(name, **kwargs):
    """Deprecated: use `rust_analyzer_toolchain_alias`.

    Args:
        name (str): The name of the target.
        **kwargs (dict): Additional keyword arguments for `rust_analyzer_toolchain_alias`.
    """

    # buildifier: disable=print
    print("`current_rust_analyzer_toolchain` is deprecated in favor of `rust_analyzer_toolchain_alias`. Please update {}".format(
        native.package_relative_label(name),
    ))

    rust_analyzer_toolchain_alias(name = name, **kwargs)

def current_rustfmt_toolchain(name, **kwargs):
    """Deprecated: use `rustfmt_toolchain_alias`.

    Args:
        name (str): The name of the target.
        **kwargs (dict): Additional keyword arguments for `rustfmt_toolchain_alias`.
    """

    # buildifier: disable=print
    print("`current_rustfmt_toolchain` is deprecated in favor of `rustfmt_toolchain_alias`. Please update {}".format(
        native.package_relative_label(name),
    ))

    rustfmt_toolchain_alias(name = name, **kwargs)
