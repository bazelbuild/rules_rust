"""Bzlmod module extensions"""

load("@bazel_features//:features.bzl", "bazel_features")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("//private:toolchain.bzl", "mdbook_toolchain_repository")
load("//private/3rdparty/crates:crates.bzl", "crate_repositories")

def _rust_ext_impl(module_ctx):
    direct_deps = []

    direct_deps.append(struct(
        repo = "rules_rust_mdbook_toolchain",
        is_dev_dep = False,
    ))
    direct_deps.extend(crate_repositories())

    maybe(
        mdbook_toolchain_repository,
        name = "rules_rust_mdbook_toolchain",
        mdbook = str(Label("//private/3rdparty/crates:mdbook__mdbook")),
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
    doc = "Dependencies for the rules_rust mdbook extension.",
    implementation = _rust_ext_impl,
)
