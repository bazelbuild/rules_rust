"""Rules for building proto libraries in Rust."""

load(
    "//proto/prost/private:prost.bzl",
    _rust_prost_library = "rust_prost_library",
    _rust_prost_toolchain = "rust_prost_toolchain",
)

def rust_prost_library(name, **kwargs):
    """A rule for generating a Rust library using Prost.

    Args:
        name (str): The name of the target.
        **kwargs (dict): Additional keyword arguments for the underlying
            `rust_prost_library` rule.
    """

    # Clippy and Rustfmt will attempt to run on these targets.
    # This is not correct and likely a bug in target detection.
    tags = kwargs.pop("tags", [])
    if "no-clippy" not in tags:
        tags.append("no-clippy")
    if "no-rustfmt" not in tags:
        tags.append("no-rustfmt")

    _rust_prost_library(
        name = name,
        tags = tags,
        **kwargs
    )

rust_prost_toolchain = _rust_prost_toolchain
