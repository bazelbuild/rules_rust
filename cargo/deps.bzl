"""
The dependencies for running the cargo_toml_info binary.
"""

load("//cargo/private/cargo_toml_info/3rdparty/crates:crates.bzl", "crate_repositories")

def cargo_dependencies():
    """Define dependencies of the `cargo` Bazel tools"""
    return crate_repositories()
