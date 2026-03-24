"""Bzlmod module extensions"""

load("//basic/3rdparty/crates:crates.bzl", basic_crate_repositories = "crate_repositories")
load("//complex/3rdparty/crates:crates.bzl", complex_crate_repositories = "crate_repositories")

def _rust_example_impl(module_ctx):
    direct_deps = []

    direct_deps.extend(basic_crate_repositories())
    direct_deps.extend(complex_crate_repositories())

    # is_dev_dep is ignored here. It's not relevant for internal_deps, as dev
    # dependencies are only relevant for module extensions that can be used
    # by other MODULES.
    return module_ctx.extension_metadata(
        root_module_direct_deps = [repo.repo for repo in direct_deps],
        root_module_direct_dev_deps = [],
    )

rust_example = module_extension(
    doc = "Dependencies for the rules_rust examples.",
    implementation = _rust_example_impl,
)
