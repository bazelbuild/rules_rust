"""Starlark tests for `rust_toolchain.opt_level`"""

load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test", "test_suite")
load("//rust:defs.bzl", "rust_binary")

def _opt_level_test(name, compilation_mode, expected_opt_level):
    target_name = "{}_{}_bin".format(name, compilation_mode)
    rust_binary(
        name = target_name,
        srcs = [":main.rs"],
        edition = "2021",
        tags = ["manual"],
    )
    analysis_test(
        name = name,
        target = target_name,
        config_settings = {
            "//command_line_option:compilation_mode": compilation_mode,
        },
        impl = _opt_level_test_impl(expected_opt_level),
    )

def _opt_level_test_impl(expected_opt_level):
    return lambda env, target: env.expect.that_target(target).action_named("Rustc").contains_at_least_args(["--codegen=opt-level={}".format(expected_opt_level)])

def _opt_level_for_dbg_test(name):
    _opt_level_test(name, "dbg", 0)

def _opt_level_for_fastbuild_test(name):
    _opt_level_test(name, "fastbuild", 0)

def _opt_level_for_opt_test(name):
    _opt_level_test(name, "opt", 3)

def opt_level_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name (str): The name of the test suite.
    """
    write_file(
        name = "bin_main",
        out = "main.rs",
        content = [
            "fn main() {}",
            "",
        ],
    )
    test_suite(
        name = name,
        tests = [
            _opt_level_for_dbg_test,
            _opt_level_for_fastbuild_test,
            _opt_level_for_opt_test,
        ],
    )
