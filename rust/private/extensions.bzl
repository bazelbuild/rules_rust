"""Bzlmod module extensions that are only used internally"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("//bindgen:repositories.bzl", "rust_bindgen_dependencies")
load("//crate_universe:repositories.bzl", "crate_universe_dependencies")
load("//proto/prost:repositories.bzl", "rust_prost_dependencies")
load("//proto/protobuf:repositories.bzl", "rust_proto_protobuf_dependencies")
load("//rust/private:repository_utils.bzl", "TINYJSON_KWARGS")
load("//test:deps.bzl", "rules_rust_test_deps")
load("//tools/rust_analyzer:deps.bzl", "rust_analyzer_dependencies")
load("//wasm_bindgen:repositories.bzl", "rust_wasm_bindgen_dependencies")

def _internal_deps_impl(module_ctx):
    # This should contain the subset of WORKSPACE.bazel that defines
    # repositories.

    # We don't want rules_rust_dependencies, as they contain things like
    # rules_cc, which is already declared in MODULE.bazel.
    direct_deps = [struct(repo = "rules_rust_tinyjson", is_dev_dep = False)]
    http_archive(**TINYJSON_KWARGS)

    direct_deps.extend(crate_universe_dependencies())
    direct_deps.extend(rust_prost_dependencies(bzlmod = True))
    direct_deps.extend(rust_proto_protobuf_dependencies(bzlmod = True))
    direct_deps.extend(rust_bindgen_dependencies())
    direct_deps.extend(rust_analyzer_dependencies())
    direct_deps.extend(rust_wasm_bindgen_dependencies())
    direct_deps.extend(rules_rust_test_deps())

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
i = module_extension(
    doc = "Dependencies for rules_rust",
    implementation = _internal_deps_impl,
)
