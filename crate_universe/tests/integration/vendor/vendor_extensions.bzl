"""Bzlmod module extension for vendored crate_universe outputs."""

load("//3rdparty/crates:crates.bzl", _external_crate_repositories = "crate_repositories")
load("//remote_manifests/crates:crates.bzl", _remote_manifests_crate_repositories = "crate_repositories")
load("//remote_pkgs/crates:crates.bzl", _remote_pkgs_crate_repositories = "crate_repositories")

def _vendored_impl(module_ctx):
    direct_deps = []
    direct_deps += _external_crate_repositories()
    direct_deps += _remote_manifests_crate_repositories()
    direct_deps += _remote_pkgs_crate_repositories()
    return module_ctx.extension_metadata(
        root_module_direct_deps = [repo.repo for repo in direct_deps],
        root_module_direct_dev_deps = [],
    )

vendored = module_extension(
    doc = "Vendored crate_universe outputs.",
    implementation = _vendored_impl,
)
