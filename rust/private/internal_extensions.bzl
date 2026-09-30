"""Bzlmod module extensions that are only used internally"""

load("@bazel_features//:features.bzl", "bazel_features")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("//rust/private:repository_utils.bzl", "TINYJSON_KWARGS")
load("//tools/rust_analyzer/3rdparty/crates:crates.bzl", _rust_analyzer_crate_repositories = "crate_repositories")

def _internal_deps_impl(module_ctx):
    direct_deps = [struct(repo = "rules_rust_tinyjson", is_dev_dep = False)]
    http_archive(**TINYJSON_KWARGS)

    direct_deps.extend(_rust_analyzer_crate_repositories())

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
i = module_extension(
    doc = "Dependencies for rules_rust",
    implementation = _internal_deps_impl,
)
