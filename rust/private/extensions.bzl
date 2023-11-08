"""Bzlmod module extensions that are only used internally"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("//rust/private:repository_utils.bzl", "TINYJSON_KWARGS")
load("//crate_universe:repositories.bzl", "crate_universe_dependencies")

def _internal_deps_impl(module_ctx):
    root_module_direct_deps = ["rules_rust_tinyjson"]
    root_module_direct_dev_deps = []

    http_archive(**TINYJSON_KWARGS)

    direct_deps = []
    direct_deps.extend(crate_universe_dependencies())

    for md in direct_deps:
        root_module_direct_deps.extend(md.direct_deps)
        root_module_direct_dev_deps.extend(getattr(md, "direct_dev_deps", []))
    return module_ctx.extension_metadata(
        root_module_direct_deps = root_module_direct_deps,
        root_module_direct_dev_deps = root_module_direct_dev_deps,
    )

internal_deps = module_extension(
    doc = "Dependencies for rules_rust",
    implementation = _internal_deps_impl,
)
