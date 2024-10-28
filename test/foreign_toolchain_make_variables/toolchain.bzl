"""Utilties for testing forwarding Make variables from toolchains."""

def _dummy_env_var_toolchain_impl(_ctx):
    make_variables = platform_common.TemplateVariableInfo({
        "ALSO_FROM_TOOLCHAIN": "absent",
        "FROM_TOOLCHAIN": "present",
    })

    return [
        platform_common.ToolchainInfo(
            make_variables = make_variables,
        ),
        make_variables,
    ]

dummy_env_var_toolchain = rule(
    implementation = _dummy_env_var_toolchain_impl,
)

def _current_dummy_env_var_toolchain_impl(ctx):
    toolchain = ctx.toolchains[str(Label("@rules_rust//test/foreign_toolchain_make_variables:toolchain_type_for_test"))]

    return [
        toolchain,
        toolchain.make_variables,
    ]

current_dummy_env_var_toolchain_toolchain = rule(
    doc = "A rule for exposing the current registered `dummy_env_var_toolchain`.",
    implementation = _current_dummy_env_var_toolchain_impl,
    toolchains = [
        str(Label("@rules_rust//test/foreign_toolchain_make_variables:toolchain_type_for_test")),
    ],
)
