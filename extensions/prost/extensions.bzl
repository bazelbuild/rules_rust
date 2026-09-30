"""Bzlmod module extensions"""

load("@bazel_features//:features.bzl", "bazel_features")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("//private/3rdparty/crates:crates.bzl", "crate_repositories")

def _rust_ext_impl(module_ctx):
    direct_deps = []

    direct_deps.extend(crate_repositories())
    direct_deps.append(struct(repo = "rrprd__heck", is_dev_dep = False))

    maybe(
        http_archive,
        name = "rrprd__heck",
        integrity = "sha256-IwTgCYP4f/s4tVtES147YKiEtdMMD8p9gv4zRJu+Veo=",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/heck/heck-0.5.0.crate"],
        strip_prefix = "heck-0.5.0",
        build_file = Label("@rules_rust_prost//private/3rdparty/crates:BUILD.heck-0.5.0.bazel"),
    )

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

rust_ext = module_extension(
    doc = "Dependencies for the rules_rust prost extension.",
    implementation = _rust_ext_impl,
)
