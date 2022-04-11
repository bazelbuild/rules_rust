"""Unittest to verify workspace status stamping is applied to environment files"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest")
load("//rust:defs.bzl", "rust_binary", "rust_library", "rust_test")
load(
    "//test/unit:common.bzl",
    "assert_action_mnemonic",
    "assert_argv_contains",
    "assert_argv_contains_not",
)

def _stamp_test_impl(ctx, force_stamp):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    action = target.actions[0]
    assert_action_mnemonic(env, action, "Rustc")

    if force_stamp:
        assert_argv_contains(env, action, "--volatile-status-file")
        assert_argv_contains(env, action, "bazel-out/volatile-status.txt")
    else:
        assert_argv_contains_not(env, action, "--volatile-status-file")
        assert_argv_contains_not(env, action, "bazel-out/volatile-status.txt")

    # Note that use of stable status invalidates targets any time it's updated.
    # This is undesirable behavior so it's intended to be excluded from the
    # Rustc action. In general this should be fine as other rules can be used
    # to produce template files for stamping in this action (ie. genrule).
    assert_argv_contains_not(env, action, "bazel-out/stable-status.txt")

    return analysistest.end(env)

def _force_stamp_test_impl(ctx):
    return _stamp_test_impl(ctx, True)

def _skip_stamp_test_impl(ctx):
    return _stamp_test_impl(ctx, False)

force_stamp_test = analysistest.make(_force_stamp_test_impl)
skip_stamp_test = analysistest.make(_skip_stamp_test_impl)

_STAMP_VALUES = (0, 1)

def _define_test_targets():
    for stamp_value in _STAMP_VALUES:
        if stamp_value == 1:
            name = "force_stamp"
            features = ["force_stamp"]
        else:
            name = "skip_stamp"
            features = ["skip_stamp"]

        rust_library(
            name = name,
            srcs = ["stamp.rs"],
            edition = "2018",
            rustc_env_files = [":stamp.env"],
            stamp = stamp_value,
            crate_features = features,
        )

        rust_test(
            name = "{}_unit_test".format(name),
            crate = ":{}".format(name),
            edition = "2018",
            rustc_env_files = [":stamp.env"],
            stamp = stamp_value,
            crate_features = features,
        )

        rust_binary(
            name = "{}_bin".format(name),
            srcs = ["stamp_main.rs"],
            edition = "2018",
            deps = [":{}".format(name)],
            rustc_env_files = [":stamp.env"],
            stamp = stamp_value,
            crate_features = features,
        )

def stamp_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name (str): Name of the macro.
    """
    _define_test_targets()

    tests = []

    for stamp_value in _STAMP_VALUES:
        if stamp_value == 1:
            test_name = "force_stamp"
            stamp_test = force_stamp_test
        else:
            test_name = "skip_stamp"
            stamp_test = skip_stamp_test

        stamp_test(
            name = "lib_{}_test".format(test_name),
            target_under_test = Label("//test/unit/stamp:{}".format(test_name)),
        )

        stamp_test(
            name = "test_{}_test".format(test_name),
            target_under_test = Label("//test/unit/stamp:{}_unit_test".format(test_name)),
        )

        stamp_test(
            name = "bin_{}_test".format(test_name),
            target_under_test = Label("//test/unit/stamp:{}_bin".format(test_name)),
        )

        tests.extend([
            "lib_{}_test".format(test_name),
            "test_{}_test".format(test_name),
            "bin_{}_test".format(test_name),
        ])

    native.test_suite(
        name = name,
        tests = tests,
    )
