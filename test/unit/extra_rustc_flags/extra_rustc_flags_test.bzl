"""Unittest to verify compile_data (attribute) propagation"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//rust:defs.bzl", "rust_library", "rust_test")
load("//test/unit:common.bzl", "assert_argv_contains", "assert_argv_contains_not")

EXTRA_FLAG = "--codegen=linker-plugin-lto"

def target_action_contains_not_flag(env, target):
    action = target.actions[0]
    asserts.equals(env, "Rustc", action.mnemonic)

    assert_argv_contains_not(
        env = env,
        action = action,
        flag = EXTRA_FLAG,
    )

def target_action_contains_flag(env, target):
    action = target.actions[0]
    asserts.equals(env, "Rustc", action.mnemonic)

    assert_argv_contains(
        env = env,
        action = action,
        flag = EXTRA_FLAG,
    )

def _extra_rustc_flags_not_present_test(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    target_action_contains_not_flag(env, target)

    return analysistest.end(env)

def _extra_rustc_flags_present_test(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    target_action_contains_flag(env, target)

    # Check the exec configuration target does NOT contain.
    target = ctx.attr.lib_exec
    target_action_contains_not_flag(env, target)

    return analysistest.end(env)

extra_rustc_flags_not_present_test = analysistest.make(_extra_rustc_flags_not_present_test)
extra_rustc_flags_present_test = analysistest.make(
    _extra_rustc_flags_present_test,
    attrs = {
        "lib_exec": attr.label(
            mandatory = True,
            cfg = "exec",
        ),
    },
    config_settings = {
        str(Label("//rust/settings:extra_rustc_flags")): [EXTRA_FLAG],
    },
)

extra_rustc_flag_present_test = analysistest.make(
    _extra_rustc_flags_present_test,
    attrs = {
        "lib_exec": attr.label(
            mandatory = True,
            cfg = "exec",
        ),
    },
    config_settings = {
        str(Label("//rust/settings:extra_rustc_flag")): [EXTRA_FLAG],
        str(Label("//rust/settings:extra_rustc_flags")): [],
    },
)

TARGET_FLAG = "--codegen=codegen-units=3"

def _extra_test_rustc_flag_applies_to_rust_test_test(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    action = target.actions[0]
    asserts.equals(env, "Rustc", action.mnemonic)
    assert_argv_contains(env = env, action = action, flag = EXTRA_FLAG)

    # The target's own rustc_flags come after the extra test flag, so they can override it.
    if EXTRA_FLAG in action.argv:
        asserts.true(
            env,
            action.argv.index(EXTRA_FLAG) < action.argv.index(TARGET_FLAG),
            "Expected {} before {} in {}".format(EXTRA_FLAG, TARGET_FLAG, action.argv),
        )

    return analysistest.end(env)

def _extra_test_rustc_flag_not_applied_to_library_test(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    target_action_contains_not_flag(env, target)

    return analysistest.end(env)

_extra_test_rustc_flag_config_settings = {
    str(Label("//rust/settings:extra_test_rustc_flag")): [EXTRA_FLAG],
}

extra_test_rustc_flag_applies_to_rust_test_test = analysistest.make(
    _extra_test_rustc_flag_applies_to_rust_test_test,
    config_settings = _extra_test_rustc_flag_config_settings,
)
extra_test_rustc_flag_not_applied_to_library_test = analysistest.make(
    _extra_test_rustc_flag_not_applied_to_library_test,
    config_settings = _extra_test_rustc_flag_config_settings,
)

def _define_test_targets():
    rust_library(
        name = "lib",
        srcs = ["lib.rs"],
        edition = "2018",
    )

    rust_test(
        name = "test",
        srcs = ["lib.rs"],
        edition = "2018",
        rustc_flags = [TARGET_FLAG],
    )

def extra_rustc_flags_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name (str): Name of the macro.
    """

    _define_test_targets()

    extra_rustc_flags_not_present_test(
        name = "extra_rustc_flags_not_present_test",
        target_under_test = ":lib",
    )

    extra_rustc_flags_present_test(
        name = "extra_rustc_flags_present_test",
        target_under_test = ":lib",
        lib_exec = ":lib",
    )

    extra_rustc_flag_present_test(
        name = "extra_rustc_flag_present_test",
        target_under_test = ":lib",
        lib_exec = ":lib",
    )

    extra_test_rustc_flag_applies_to_rust_test_test(
        name = "extra_test_rustc_flag_applies_to_rust_test_test",
        target_under_test = ":test",
    )

    extra_test_rustc_flag_not_applied_to_library_test(
        name = "extra_test_rustc_flag_not_applied_to_library_test",
        target_under_test = ":lib",
    )

    native.test_suite(
        name = name,
        tests = [
            ":extra_rustc_flags_not_present_test",
            ":extra_rustc_flags_present_test",
            ":extra_test_rustc_flag_applies_to_rust_test_test",
            ":extra_test_rustc_flag_not_applied_to_library_test",
        ],
    )
