"""
The dependencies for running the cargo_toml_info binary.
"""

load(
    "//cargo/cargo_toml_variable_extractor/3rdparty/crates:crates.bzl",
    cargo_toml_variable_extractor_repositories = "crate_repositories",
)
load(
    "//cargo/private/cargo_toml_info/3rdparty/crates:crates.bzl",
    cargo_toml_info_repositories = "crate_repositories",
)

def cargo_dependencies():
    """Define dependencies of the `cargo` Bazel tools

    Returns:
        list: A list of all defined repositories.
    """
    direct_deps = []
    direct_deps.extend(cargo_toml_variable_extractor_repositories())
    direct_deps.extend(cargo_toml_info_repositories())

    return direct_deps
