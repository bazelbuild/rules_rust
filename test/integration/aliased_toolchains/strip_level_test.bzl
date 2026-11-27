"""Tests that `rust.toolchain(strip_level = ...)` reaches the Rustc command line."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

def _strip_level_test_impl(ctx, expected_level):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    action = target.actions[0]
    asserts.equals(env, "Rustc", action.mnemonic)

    flag = "--codegen=strip={}".format(expected_level)
    asserts.true(
        env,
        flag in action.argv,
        "Expected {} to contain {}".format(action.argv, flag),
    )
    return analysistest.end(env)

def _strip_level_for_dbg_test_impl(ctx):
    return _strip_level_test_impl(ctx, "none")

_strip_level_for_dbg_test = analysistest.make(
    _strip_level_for_dbg_test_impl,
    config_settings = {
        "//command_line_option:compilation_mode": "dbg",
    },
)

def _strip_level_for_fastbuild_test_impl(ctx):
    return _strip_level_test_impl(ctx, "debuginfo")

_strip_level_for_fastbuild_test = analysistest.make(
    _strip_level_for_fastbuild_test_impl,
    config_settings = {
        "//command_line_option:compilation_mode": "fastbuild",
    },
)

def strip_level_test_suite(name, target_under_test):
    """Checks the strip level set in `MODULE.bazel` for each compilation mode.

    Args:
        name (str): The name of the test suite.
        target_under_test (str): A `rust_binary` built with the registered toolchain.
    """
    _strip_level_for_dbg_test(
        name = "strip_level_for_dbg_test",
        target_under_test = target_under_test,
    )

    _strip_level_for_fastbuild_test(
        name = "strip_level_for_fastbuild_test",
        target_under_test = target_under_test,
    )

    native.test_suite(
        name = name,
        tests = [
            ":strip_level_for_dbg_test",
            ":strip_level_for_fastbuild_test",
        ],
    )
