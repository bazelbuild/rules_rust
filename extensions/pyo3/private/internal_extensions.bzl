"""Bzlmod module extensions"""

def _rust_ext_impl(module_ctx):
    return module_ctx.extension_metadata(
        root_module_direct_deps = [],
        root_module_direct_dev_deps = [],
    )

rust_ext = module_extension(
    doc = "Dependencies for pyo3 rules extension.",
    implementation = _rust_ext_impl,
)
