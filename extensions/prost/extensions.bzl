"""Bzlmod module extensions"""

load("@bazel_features//:features.bzl", "bazel_features")

def _rust_ext_impl(module_ctx):
    metadata_kwargs = {
        "root_module_direct_deps": [],
        "root_module_direct_dev_deps": [],
    }

    if bazel_features.external_deps.extension_metadata_has_reproducible:
        metadata_kwargs["reproducible"] = True

    return module_ctx.extension_metadata(**metadata_kwargs)

rust_ext = module_extension(
    doc = "Dependencies for the rules_rust prost extension.",
    implementation = _rust_ext_impl,
)
