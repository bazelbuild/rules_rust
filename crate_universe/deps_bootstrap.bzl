"""A module is used to assist in bootstrapping cargo-bazel"""

load("@rules_rust//cargo:defs.bzl", "cargo_bootstrap_repository")
load("//private:srcs.bzl", "CARGO_BAZEL_SRCS")

def cargo_bazel_bootstrap(name = "cargo_bazel_bootstrap", rust_version = None):
    """An optional repository which bootstraps `cargo-bazel` for use with `crates_repository`

    Args:
        name (str, optional): The name of the `cargo_bootstrap_repository`.
        rust_version (str, optional): The rust version to use. Defaults to the default of `cargo_bootstrap_repository`.
    """
    cargo_bootstrap_repository(
        name = name,
        srcs = CARGO_BAZEL_SRCS,
        binary = "cargo-bazel",
        cargo_lockfile = "@cargo_bazel//:Cargo.lock",
        cargo_toml = "@cargo_bazel//:Cargo.toml",
        version = rust_version,
        # The increased timeout helps avoid flakes in CI
        timeout = 900,
    )
