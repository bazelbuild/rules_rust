"""
"""

load("@bazel_skylib//rules:copy_file.bzl", "copy_file")
load("@rules_python//python:python.bzl", "py_library")
load("@rules_rust//rust:rust.bzl", "rust_library")

def py_rust_library(name, **kwargs):
    """
    Wraps a rust shared library that implements a python native extension to be usable by @rules_python targets.

    Typically this is done through the use of a crate such as `pyo3` or `cpython`.

    Args:
        name (str): A unique name for this target.
        **kwargs:   Passed directly to rust_library.
    """

    mangled = name + "_mangled_so"
    rust_library(
        name = mangled,
        crate_type = "cdylib",
        rustc_flags = select({
            "@rules_rust//rust/platform:osx": [
                "--codegen=link-arg=-undefined",
                "--codegen=link-arg=dynamic_lookup",
            ],
            "//conditions:default": [],
        }),
        **kwargs
    )

    unix = name + "_unix"
    copy_file(
        name = unix,
        src = mangled,
        out = name + ".so",
    )
    windows = name + "_windows"
    copy_file(
        name = windows,
        src = mangled,
        out = name + ".pyd",
    )
    py_library(
        name = name,
        data = select({
            "@rules_rust//rust/platform:windows": [windows],
            "//conditions:default": [unix],
        }),
    )
