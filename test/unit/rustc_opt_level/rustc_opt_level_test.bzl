"""Unit test to verify rustc optimization and debug flags"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//rust:defs.bzl", "rust_library")
load("//test/unit:common.bzl", "assert_argv_contains")

def _rustc_opt_level_test(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    action = target.actions[0]
    asserts.equals(env, "Rustc", action.mnemonic)

    assert_argv_contains(
        env = env,
        action = action,
        flag = "--codegen=debuginfo=" + ctx.attr._expect_debuginfo,
    )

    assert_argv_contains(
        env = env,
        action = action,
        flag = "--codegen=opt-level=" + ctx.attr._expect_opt_level,
    )

    return analysistest.end(env)

#
# Test cases verifying the default behavior of the debug info and opt level
# flags
#

rustc_opt_level_default_dbg_test = analysistest.make(
    _rustc_opt_level_test,
    attrs = {
        "_expect_debuginfo": attr.string(default = "2"),
        "_expect_opt_level": attr.string(default = "0"),
    },
    config_settings = {
        "//command_line_option:compilation_mode": "dbg",
    },
)

rustc_opt_level_default_fastbuild_test = analysistest.make(
    _rustc_opt_level_test,
    attrs = {
        "_expect_debuginfo": attr.string(default = "0"),
        "_expect_opt_level": attr.string(default = "0"),
    },
    config_settings = {
        "//command_line_option:compilation_mode": "fastbuild",
    },
)

rustc_opt_level_default_opt_test = analysistest.make(
    _rustc_opt_level_test,
    attrs = {
        "_expect_debuginfo": attr.string(default = "0"),
        "_expect_opt_level": attr.string(default = "3"),
    },
    config_settings = {
        "//command_line_option:compilation_mode": "opt",
    },
)

#
# Tests verifying that a single config setting will change all of the debug
# info and opt level (for each compilation mode)
#

rustc_opt_level_override_single_dbg_test = analysistest.make(
    _rustc_opt_level_test,
    attrs = {
        "_expect_debuginfo": attr.string(default = "1"),
        "_expect_opt_level": attr.string(default = "s"),
    },
    config_settings = {
        "//command_line_option:compilation_mode": "dbg",
        "@//rust/settings:debug_info": ["1"],
        "@//rust/settings:opt_level": ["s"],
    },
)

rustc_opt_level_override_single_fastbuild_test = analysistest.make(
    _rustc_opt_level_test,
    attrs = {
        "_expect_debuginfo": attr.string(default = "1"),
        "_expect_opt_level": attr.string(default = "s"),
    },
    config_settings = {
        "//command_line_option:compilation_mode": "fastbuild",
        "@//rust/settings:debug_info": ["1"],
        "@//rust/settings:opt_level": ["s"],
    },
)

rustc_opt_level_override_single_opt_test = analysistest.make(
    _rustc_opt_level_test,
    attrs = {
        "_expect_debuginfo": attr.string(default = "1"),
        "_expect_opt_level": attr.string(default = "s"),
    },
    config_settings = {
        "//command_line_option:compilation_mode": "opt",
        "@//rust/settings:debug_info": ["1"],
        "@//rust/settings:opt_level": ["s"],
    },
)

#
# Tests verifying that a multiple config settings will change each of the debug
# info and opt level (for each compilation mode)
#

rustc_opt_level_override_multi_dbg_test = analysistest.make(
    _rustc_opt_level_test,
    attrs = {
        "_expect_debuginfo": attr.string(default = "2"),
        "_expect_opt_level": attr.string(default = "0"),
    },
    config_settings = {
        "//command_line_option:compilation_mode": "dbg",
        "@//rust/settings:debug_info": ["2", "1", "1"],
        "@//rust/settings:opt_level": ["0", "1", "s"],
    },
)

rustc_opt_level_override_multi_fastbuild_test = analysistest.make(
    _rustc_opt_level_test,
    attrs = {
        "_expect_debuginfo": attr.string(default = "1"),
        "_expect_opt_level": attr.string(default = "1"),
    },
    config_settings = {
        "//command_line_option:compilation_mode": "fastbuild",
        "@//rust/settings:debug_info": ["2", "1", "1"],
        "@//rust/settings:opt_level": ["0", "1", "s"],
    },
)

rustc_opt_level_override_multi_opt_test = analysistest.make(
    _rustc_opt_level_test,
    attrs = {
        "_expect_debuginfo": attr.string(default = "1"),
        "_expect_opt_level": attr.string(default = "s"),
    },
    config_settings = {
        "//command_line_option:compilation_mode": "opt",
        "@//rust/settings:debug_info": ["2", "1", "1"],
        "@//rust/settings:opt_level": ["0", "1", "s"],
    },
)

def _define_test_targets():
    rust_library(
        name = "lib",
        srcs = ["lib.rs"],
        edition = "2018",
    )

def rustc_opt_level_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name (str): Name of the macro.
    """

    _define_test_targets()

    rustc_opt_level_default_dbg_test(
        name = "rustc_opt_level_default_dbg_test",
        target_under_test = ":lib",
    )

    rustc_opt_level_default_fastbuild_test(
        name = "rustc_opt_level_default_fastbuild_test",
        target_under_test = ":lib",
    )

    rustc_opt_level_default_opt_test(
        name = "rustc_opt_level_default_opt_test",
        target_under_test = ":lib",
    )

    rustc_opt_level_override_single_dbg_test(
        name = "rustc_opt_level_override_single_dbg_test",
        target_under_test = ":lib",
    )

    rustc_opt_level_override_single_fastbuild_test(
        name = "rustc_opt_level_override_single_fastbuild_test",
        target_under_test = ":lib",
    )

    rustc_opt_level_override_single_opt_test(
        name = "rustc_opt_level_override_single_opt_test",
        target_under_test = ":lib",
    )

    rustc_opt_level_override_multi_dbg_test(
        name = "rustc_opt_level_override_multi_dbg_test",
        target_under_test = ":lib",
    )

    rustc_opt_level_override_multi_fastbuild_test(
        name = "rustc_opt_level_override_multi_fastbuild_test",
        target_under_test = ":lib",
    )

    rustc_opt_level_override_multi_opt_test(
        name = "rustc_opt_level_override_multi_opt_test",
        target_under_test = ":lib",
    )

    native.test_suite(
        name = name,
        tests = [
            ":rustc_opt_level_default_dbg_test",
            ":rustc_opt_level_default_fastbuild_test",
            ":rustc_opt_level_default_opt_test",
            ":rustc_opt_level_override_single_dbg_test",
            ":rustc_opt_level_override_single_fastbuild_test",
            ":rustc_opt_level_override_single_opt_test",
            ":rustc_opt_level_override_multi_dbg_test",
            ":rustc_opt_level_override_multi_fastbuild_test",
            ":rustc_opt_level_override_multi_opt_test",
        ],
    )
