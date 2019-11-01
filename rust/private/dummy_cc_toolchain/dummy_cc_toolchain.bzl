def _dummy_cc_toolchain_impl(ctx):
    return [platform_common.ToolchainInfo()]

dummy_cc_toolchain = rule(
    implementation = _dummy_cc_toolchain_impl,
    attrs = {},
)
