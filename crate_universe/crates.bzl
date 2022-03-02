"""A module defining dependencies of the `cargo-bazel` Rust target"""

load("@rules_rust//rust:defs.bzl", "rust_common")
load("//:defs.bzl", "crate", "crates_repository", "crates_vendor")
load("//:deps_bootstrap.bzl", "cargo_bazel_bootstrap")
load("//3rdparty:third_party_deps.bzl", "third_party_deps")
load("//3rdparty/crates:crates.bzl", _vendor_crate_repositories = "crate_repositories")

USE_CRATES_REPOSITORY = False

_REPOSITORY_NAME = "crate_index"

_ANNOTATIONS = {
    "libgit2-sys": [crate.annotation(
        gen_build_script = False,
        deps = ["@libgit2"],
    )],
    "libz-sys": [crate.annotation(
        gen_build_script = False,
        deps = ["@zlib"],
    )],
}

_MANIFESTS = [
    "@cargo_bazel//:Cargo.toml",
    "@cargo_bazel//tools/cross_installer:Cargo.toml",
    "@cargo_bazel//tools/examples_runner:Cargo.toml",
    "@cargo_bazel//tools/urls_generator:Cargo.toml",
]

def crate_deps_repository(rust_version = rust_common.default_version, bootstrap = False):
    """Define dependencies of the `cargo-bazel` Rust target

    Args:
        rust_version (str, optional): The version of rust to use when generating dependencies.
        bootstrap (bool, optional): If true, a `cargo_bootstrap_repository` target will be generated.
    """
    third_party_deps()

    cargo_bazel_bootstrap(rust_version = rust_version)

    if USE_CRATES_REPOSITORY:
        crates_repository(
            name = _REPOSITORY_NAME,
            annotations = _ANNOTATIONS,
            generator = "@cargo_bazel_bootstrap//:cargo-bazel" if bootstrap else None,
            lockfile = "@cargo_bazel//:Cargo.Bazel.lock",
            manifests = _MANIFESTS,
            rust_version = rust_version,
        )

    else:
        _vendor_crate_repositories()

def crate_deps_target(name = "crates_vendor", vendor_path = "crates"):
    crates_vendor(
        name = name,
        repository_name = _REPOSITORY_NAME,
        annotations = _ANNOTATIONS,
        manifests = _MANIFESTS,
        vendor_path = vendor_path,
        mode = "remote",
        tags = ["manual"],
    )
