"""Analysis tests for `//rust/settings:toolchain_linker_wrapper`."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//rust:defs.bzl", "rust_binary")

_TOOLCHAIN_TYPE = str(Label("//rust:toolchain_type"))

_WRAPPER_SETTINGS = {
    # The mock linker cannot execute, so coverage must not build :bin or its exec tools.
    "//command_line_option:collect_code_coverage": False,
    str(Label("//rust/settings:toolchain_linker_preference")): "rust",
    str(Label("//rust/settings:toolchain_linker_wrapper")): str(Label(":mock_linker_file")),
}

_ToolchainLinkerInfo = provider(
    doc = "The `linker` of the Rust toolchain resolved for a target.",
    fields = {"linker": "File: `ToolchainInfo.linker`."},
)

def _toolchain_linker_impl(ctx):
    return [_ToolchainLinkerInfo(linker = ctx.toolchains[_TOOLCHAIN_TYPE].linker)]

_toolchain_linker = rule(
    implementation = _toolchain_linker_impl,
    doc = "Exposes the `linker` of the Rust toolchain resolved in this configuration.",
    toolchains = [_TOOLCHAIN_TYPE],
)

def _exec_toolchain_linker_impl(ctx):
    return [ctx.attr.toolchain_linker[_ToolchainLinkerInfo]]

# `config_settings` only reach `target_under_test`, so the exec dependency has to hang off the
# target under test rather than off the test rule itself.
_exec_toolchain_linker = rule(
    implementation = _exec_toolchain_linker_impl,
    doc = "Forwards the `linker` of the Rust toolchain resolved in the exec configuration.",
    attrs = {
        "toolchain_linker": attr.label(
            cfg = "exec",
            mandatory = True,
            providers = [_ToolchainLinkerInfo],
        ),
    },
)

def _is_mock_linker(file):
    return file != None and file.basename == "mock_linker"

def _wrapper_used_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = [a for a in analysistest.target_actions(env) if a.mnemonic == "Rustc"]
    asserts.equals(env, 1, len(actions))
    action = actions[0]

    wrappers = [f for f in action.inputs.to_list() if _is_mock_linker(f)]
    asserts.equals(env, 1, len(wrappers), "The linker wrapper must be an input of the Rustc action")
    if wrappers:
        linker_args = [arg for arg in action.argv if arg.startswith("--codegen=linker=")]
        asserts.equals(env, ["--codegen=linker=" + wrappers[0].path], linker_args)

    return analysistest.end(env)

def _wrapper_exec_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    asserts.true(
        env,
        _is_mock_linker(target[_ToolchainLinkerInfo].linker),
        "The linker wrapper must also apply to the exec configuration",
    )
    return analysistest.end(env)

def _wrapper_unset_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    asserts.false(env, _is_mock_linker(target[_ToolchainLinkerInfo].linker))
    return analysistest.end(env)

wrapper_used_test = analysistest.make(
    _wrapper_used_test_impl,
    config_settings = _WRAPPER_SETTINGS,
)

wrapper_exec_test = analysistest.make(
    _wrapper_exec_test_impl,
    config_settings = _WRAPPER_SETTINGS,
)

wrapper_unset_test = analysistest.make(_wrapper_unset_test_impl)

def toolchain_linker_wrapper_test_suite(name):
    """Entry-point macro for `toolchain_linker_wrapper` tests.

    Args:
        name: test suite name
    """
    write_file(
        name = "mock_linker_file",
        out = "mock_linker",
        content = [],
        is_executable = True,
    )

    rust_binary(
        name = "bin",
        srcs = ["main.rs"],
        edition = "2021",
        tags = ["manual"],
    )

    _toolchain_linker(
        name = "toolchain_linker",
        tags = ["manual"],
    )

    _exec_toolchain_linker(
        name = "exec_toolchain_linker",
        toolchain_linker = ":toolchain_linker",
        tags = ["manual"],
    )

    wrapper_used_test(
        name = "wrapper_used_test",
        target_under_test = ":bin",
    )

    wrapper_exec_test(
        name = "wrapper_exec_test",
        target_under_test = ":exec_toolchain_linker",
    )

    wrapper_unset_test(
        name = "wrapper_unset_test",
        target_under_test = ":toolchain_linker",
    )

    native.test_suite(
        name = name,
        tests = [
            ":wrapper_exec_test",
            ":wrapper_unset_test",
            ":wrapper_used_test",
        ],
    )
