# buildifier: disable=module-docstring
def _dummy_cc_toolchain_impl(_ctx):
    # The `all_files` attribute is referenced by rustc_compile_action().
    return [platform_common.ToolchainInfo(all_files = depset([]))]

dummy_cc_toolchain = rule(
    implementation = _dummy_cc_toolchain_impl,
    attrs = {},
)
