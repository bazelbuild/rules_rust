"""Starlark unit tests for the bootstrap process wrapper"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//test/unit:common.bzl", "assert_action_mnemonic")

def _enable_sh_toolchain_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    if ctx.attr.expected_ext == ".bat":
        assert_action_mnemonic(env, target.actions[0], "ExecutableSymlink")
    else:
        assert_action_mnemonic(env, target.actions[0], "TemplateExpand")

    return analysistest.end(env)

_enable_sh_toolchain_test = analysistest.make(
    _enable_sh_toolchain_test_impl,
    config_settings = {
        str(Label("//rust/settings:experimental_use_sh_toolchain_for_bootstrap_process_wrapper")): True,
    },
    attrs = {
        "expected_ext": attr.string(
            doc = "The expected extension for the bootstrap script.",
            mandatory = True,
            values = [
                ".bat",
                ".sh",
            ],
        ),
    },
)

def _disable_sh_toolchain_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    assert_action_mnemonic(env, target.actions[0], "ExecutableSymlink")

    return analysistest.end(env)

_disable_sh_toolchain_test = analysistest.make(
    _disable_sh_toolchain_test_impl,
    config_settings = {
        str(Label("//rust/settings:experimental_use_sh_toolchain_for_bootstrap_process_wrapper")): False,
    },
)

def _process_wrapper_is_bootstrapped_test_impl(ctx):
    """The process wrapper is compiled through the bootstrap script, not through itself.

    Its rustc flags go through a param file like everyone else's, which the
    script rewrites. Analysis cannot see the param file (`argv` is the
    expanded command line and the file is no input), so that part is covered
    by `bootstrap_process_wrapper_test` and by the build itself.
    """
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    actions = [action for action in target.actions if action.mnemonic == "Rustc"]
    asserts.equals(env, 1, len(actions), "one rustc action")
    executable = actions[0].argv[0].split("/")[-1]
    asserts.true(
        env,
        executable.startswith("bootstrap_process_wrapper"),
        "Expected the process wrapper to be compiled through the bootstrap script, got {}".format(executable),
    )

    return analysistest.end(env)

_process_wrapper_is_bootstrapped_test = analysistest.make(_process_wrapper_is_bootstrapped_test_impl)

def process_wrapper_bootstrap_test_suite(name, **kwargs):
    """Entry-point macro called from the BUILD file.

    Args:
        name (str): Name of the macro.
        **kwargs (dict): Additional keyword arguments.
    """

    _enable_sh_toolchain_test(
        name = "enable_sh_toolchain_test",
        target_under_test = Label("//util/process_wrapper:bootstrap_process_wrapper"),
        expected_ext = select({
            "@platforms//os:windows": ".bat",
            "//conditions:default": ".sh",
        }),
    )

    _disable_sh_toolchain_test(
        name = "disable_sh_toolchain_test",
        target_under_test = Label("//util/process_wrapper:bootstrap_process_wrapper"),
    )

    _process_wrapper_is_bootstrapped_test(
        name = "process_wrapper_is_bootstrapped_test",
        target_under_test = Label("//util/process_wrapper"),
    )

    native.test_suite(
        name = name,
        tests = [
            ":disable_sh_toolchain_test",
            ":enable_sh_toolchain_test",
            ":process_wrapper_is_bootstrapped_test",
        ],
        **kwargs
    )
