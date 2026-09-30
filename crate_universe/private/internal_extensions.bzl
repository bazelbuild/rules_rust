"""Bzlmod module extensions that are only used internally"""

load("@bazel_features//:features.bzl", "bazel_features")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("//cargo:defs.bzl", "cargo_bootstrap_repository")
load("//cargo/3rdparty/crates:crates.bzl", _cargo_crate_repositories = "crate_repositories")
load("//crate_universe/3rdparty:third_party_deps.bzl", "third_party_deps")
load("//crate_universe/3rdparty/crates:crates.bzl", _vendor_crate_repositories = "crate_repositories")
load("//crate_universe/private:srcs.bzl", "CARGO_BAZEL_SRCS")
load("//crate_universe/private:vendor_utils.bzl", "crates_vendor_deps")
load("//crate_universe/tools/cross_installer:cross_installer_deps.bzl", "cross_installer_deps")

# buildifier: disable=bzl-visibility
load("//rust/private:common.bzl", "rust_common")

def _internal_deps_impl(module_ctx):
    direct_deps = []

    third_party_deps()
    direct_deps.extend(_vendor_crate_repositories())
    direct_deps.extend(crates_vendor_deps())

    # We call this, so that crate_universe users get the deps, but we _don't_ add them to direct_deps.
    # For bzlmod these deps were already added as rules_rust internal deps, and if we add them here we get warnings about duplicates.
    _cargo_crate_repositories()

    # is_dev_dep is ignored here. It's not relevant for internal_deps, as dev
    # dependencies are only relevant for module extensions that can be used
    # by other MODULES.
    metadata_kwargs = {
        "root_module_direct_deps": [repo.repo for repo in direct_deps],
        "root_module_direct_dev_deps": [],
    }

    if bazel_features.external_deps.extension_metadata_has_reproducible:
        metadata_kwargs["reproducible"] = True

    return module_ctx.extension_metadata(**metadata_kwargs)

# This is named a single character to reduce the size of path names when running build scripts, to reduce the chance
# of hitting the 260 character windows path name limit.
# TODO: https://github.com/bazelbuild/rules_rust/issues/1120
cu = module_extension(
    doc = "Dependencies for crate_universe.",
    implementation = _internal_deps_impl,
)

def _internal_non_reproducible_deps_impl(module_ctx):
    direct_deps = []

    maybe(
        cargo_bootstrap_repository,
        name = "cargo_bazel_bootstrap",
        srcs = CARGO_BAZEL_SRCS,
        binary = "cargo-bazel",
        cargo_lockfile = "@rules_rust//crate_universe:Cargo.lock",
        cargo_toml = "@rules_rust//crate_universe:Cargo.toml",
        version = rust_common.default_version,
        rust_toolchain_cargo_template = "@rust_host_tools//:bin/{tool}",
        rust_toolchain_rustc_template = "@rust_host_tools//:bin/{tool}",
        compressed_windows_toolchain_names = False,
        # The increased timeout helps avoid flakes in CI
        timeout = 900,
    )

    direct_deps.append(struct(
        repo = "cargo_bazel_bootstrap",
        is_dev_dep = False,
    ))

    # is_dev_dep is ignored here. It's not relevant for internal_deps, as dev
    # dependencies are only relevant for module extensions that can be used
    # by other MODULES.
    return module_ctx.extension_metadata(
        root_module_direct_deps = [repo.repo for repo in direct_deps],
        root_module_direct_dev_deps = [],
    )

# This is named a single character to reduce the size of path names when running build scripts, to reduce the chance
# of hitting the 260 character windows path name limit.
# TODO: https://github.com/bazelbuild/rules_rust/issues/1120
cu_nr = module_extension(
    doc = "Dependencies for crate_universe (non reproducible).",
    implementation = _internal_non_reproducible_deps_impl,
)

def _internal_dev_deps_impl(module_ctx):
    direct_deps = []

    direct_deps.extend(cross_installer_deps(
        rust_toolchain_cargo_template = "@rust_host_tools//:bin/{tool}",
        rust_toolchain_rustc_template = "@rust_host_tools//:bin/{tool}",
        compressed_windows_toolchain_names = False,
    ))

    # is_dev_dep is ignored here. It's not relevant for internal_deps, as dev
    # dependencies are only relevant for module extensions that can be used
    # by other MODULES.
    return module_ctx.extension_metadata(
        root_module_direct_deps = [],
        root_module_direct_dev_deps = [repo.repo for repo in direct_deps],
    )

# This is named a single character to reduce the size of path names when running build scripts, to reduce the chance
# of hitting the 260 character windows path name limit.
# TODO: https://github.com/bazelbuild/rules_rust/issues/1120
cu_dev = module_extension(
    doc = "Development dependencies for crate_universe.",
    implementation = _internal_dev_deps_impl,
)
