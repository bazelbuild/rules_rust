"""Bzlmod module extensions"""

load("@bazel_features//:features.bzl", "bazel_features")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("//3rdparty/crates:crates.bzl", "crate_repositories")

BINDGEN_VERSION = "0.71.1"

def _rust_ext_impl(module_ctx):
    direct_deps = []

    bindgen_name = "rules_rust_bindgen__bindgen-cli-{}".format(BINDGEN_VERSION)
    maybe(
        http_archive,
        name = bindgen_name,
        integrity = "sha256-/e0QyglWr9DL5c+JzHGuGmeeZbghbGUfyhe6feisVNw=",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/bindgen-cli/bindgen-cli-{}.crate".format(BINDGEN_VERSION)],
        strip_prefix = "bindgen-cli-{}".format(BINDGEN_VERSION),
        build_file = Label("//3rdparty:BUILD.bindgen-cli.bazel"),
    )
    direct_deps.append(struct(repo = bindgen_name, is_dev_dep = False))
    direct_deps.extend(crate_repositories())

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
    doc = "Dependencies for the rules_rust_bindgen extension.",
    implementation = _rust_ext_impl,
)
