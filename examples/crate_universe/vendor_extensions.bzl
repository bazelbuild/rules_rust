"""Bzlmod module extensions"""

load("@bazel_ci_rules//:rbe_repo.bzl", "rbe_preconfig")
load(
    "//vendor_external/crates:crates.bzl",
    crates_vendor_external_repositories = "crate_repositories",
)
load(
    "//vendor_remote_manifests/crates:crates.bzl",
    crates_vendor_manifests_repositories = "crate_repositories",
)
load(
    "//vendor_remote_pkgs/crates:crates.bzl",
    crates_vendor_packages_repositories = "crate_repositories",
)

def _vendored_impl(module_ctx):
    # This should contain the subset of WORKSPACE.bazel that defines
    # repositories.
    direct_deps = []

    direct_deps.extend(crates_vendor_external_repositories())
    direct_deps.extend(crates_vendor_manifests_repositories())
    direct_deps.extend(crates_vendor_packages_repositories())

    # is_dev_dep is ignored here. It's not relevant for internal_deps, as dev
    # dependencies are only relevant for module extensions that can be used
    # by other MODULES.
    return module_ctx.extension_metadata(
        root_module_direct_deps = [repo.repo for repo in direct_deps],
        root_module_direct_dev_deps = [],
    )

vendored = module_extension(
    doc = "Vendored crate_universe outputs.",
    implementation = _vendored_impl,
)

def _dev_impl(module_ctx):
    # This should contain the subset of WORKSPACE.bazel that defines
    # repositories.
    direct_deps = []

    # Creates a default toolchain config for RBE.
    # Use this as is if you are using the rbe_ubuntu16_04 container,
    # otherwise refer to RBE docs.
    direct_deps.append(struct(repo = "buildkite_config"))
    rbe_preconfig(
        name = "buildkite_config",
        toolchain = "ubuntu1804-bazel-java11",
    )

    # is_dev_dep is ignored here. It's not relevant for internal_deps, as dev
    # dependencies are only relevant for module extensions that can be used
    # by other MODULES.
    return module_ctx.extension_metadata(
        root_module_direct_deps = [],
        root_module_direct_dev_deps = [repo.repo for repo in direct_deps],
    )

dev = module_extension(
    doc = "Development dependencies.",
    implementation = _dev_impl,
)
