"""Unittest to verify workspace status stamping is applied to environment files"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest")
load("//rust:defs.bzl", "rust_binary", "rust_common", "rust_library", "rust_test")
load(
    "//test/unit:common.bzl",
    "assert_action_mnemonic",
    "assert_argv_contains",
    "assert_argv_contains_not",
)

def _assert_stamped(env, action):
    assert_argv_contains(env, action, "--volatile-status-file")
    assert_argv_contains(env, action, "bazel-out/volatile-status.txt")

def _assert_not_stamped(env, action):
    assert_argv_contains_not(env, action, "--volatile-status-file")
    assert_argv_contains_not(env, action, "bazel-out/volatile-status.txt")

def _assert_no_stable_status(env, action):
    # Note that use of stable status invalidates targets any time it's updated.
    # This is undesirable behavior so it's intended to be excluded from the
    # Rustc action. In general this should be fine as other rules can be used
    # to produce template files for stamping in this action (ie. genrule).
    assert_argv_contains_not(env, action, "bazel-out/stable-status.txt")

def _explicit_stamp_test_impl(ctx, force_stamp):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    action = target.actions[0]
    assert_action_mnemonic(env, action, "Rustc")

    if force_stamp:
        _assert_stamped(env, action)
    else:
        _assert_not_stamped(env, action)

    _assert_no_stable_status(env, action)

    return analysistest.end(env)

def _stamp_build_flag_test_impl(ctx, should_stamp):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    action = target.actions[0]
    assert_action_mnemonic(env, action, "Rustc")

    is_test = target[rust_common.crate_info].is_test
    is_bin = target[rust_common.crate_info].type == "bin"

    # bazel build --stamp should lead to stamped rust binaries, but not
    # libraries and tests.
    if should_stamp:
        if is_bin and not is_test:
            _assert_stamped(env, action)
        else:
            _assert_not_stamped(env, action)
    else:
        _assert_not_stamped(env, action)

    _assert_no_stable_status(env, action)

    return analysistest.end(env)

def _force_stamp_test_impl(ctx):
    return _explicit_stamp_test_impl(ctx, True)

def _skip_stamp_test_impl(ctx):
    return _explicit_stamp_test_impl(ctx, False)

def _stamp_build_flag_is_true_impl(ctx):
    return _stamp_build_flag_test_impl(ctx, True)

def _stamp_build_flag_is_false_impl(ctx):
    return _stamp_build_flag_test_impl(ctx, False)

force_stamp_test = analysistest.make(_force_stamp_test_impl)
skip_stamp_test = analysistest.make(_skip_stamp_test_impl)
stamp_build_flag_is_true_test = analysistest.make(
    _stamp_build_flag_is_true_impl,
    config_settings = {
        "//command_line_option:stamp": True,
    },
)
stamp_build_flag_is_false_test = analysistest.make(
    _stamp_build_flag_is_false_impl,
    config_settings = {
        "//command_line_option:stamp": False,
    },
)

_STAMP_VALUES = (0, 1)

def _define_test_targets():
    for stamp_value in _STAMP_VALUES:
        if stamp_value == 1:
            name = "force_stamp"
            features = ["force_stamp"]
            stamp_build_flag_target_name = "with_stamp_build_flag"
        else:
            name = "skip_stamp"
            features = ["skip_stamp"]
            stamp_build_flag_target_name = "without_stamp_build_flag"

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

        rust_library(
            name = "{}_lib".format(stamp_build_flag_target_name),
            srcs = ["stamp.rs"],
            rustc_env_files = ["stamp.env"],
            edition = "2018",
        )

        rust_binary(
            name = "{}_bin".format(stamp_build_flag_target_name),
            srcs = ["stamp_main.rs"],
            edition = "2018",
            deps = ["{}_lib".format(stamp_build_flag_target_name)],
            crate_features = [stamp_build_flag_target_name],
            rustc_env_files = ["stamp.env"],
        )

        rust_test(
            name = "{}_test".format(stamp_build_flag_target_name),
            crate = "{}_lib".format(stamp_build_flag_target_name),
            edition = "2018",
            rustc_env_files = ["stamp.env"],
            # Building with --stamp should not affect tests
            crate_features = ["skip_stamp"],
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
            explicit_stamp_test_name = "force_stamp"
            stamp_test = force_stamp_test
            stamp_build_flag_test_name = "with_stamp_build_flag"
            build_flag_stamp_test = stamp_build_flag_is_true_test
        else:
            explicit_stamp_test_name = "skip_stamp"
            stamp_test = skip_stamp_test
            stamp_build_flag_test_name = "without_stamp_build_flag"
            build_flag_stamp_test = stamp_build_flag_is_false_test

        stamp_test(
            name = "lib_{}_test".format(explicit_stamp_test_name),
            target_under_test = Label("//test/unit/stamp:{}".format(explicit_stamp_test_name)),
        )

        stamp_test(
            name = "test_{}_test".format(explicit_stamp_test_name),
            target_under_test = Label("//test/unit/stamp:{}_unit_test".format(explicit_stamp_test_name)),
        )

        stamp_test(
            name = "bin_{}_test".format(explicit_stamp_test_name),
            target_under_test = Label("//test/unit/stamp:{}_bin".format(explicit_stamp_test_name)),
        )

        build_flag_stamp_test(
            name = "lib_{}_test".format(stamp_build_flag_test_name),
            target_under_test = "{}_lib".format(stamp_build_flag_test_name),
        )

        build_flag_stamp_test(
            name = "bin_{}_test".format(stamp_build_flag_test_name),
            target_under_test = "{}_bin".format(stamp_build_flag_test_name),
        )

        build_flag_stamp_test(
            name = "test_{}_test".format(stamp_build_flag_test_name),
            target_under_test = "{}_test".format(stamp_build_flag_test_name),
        )

        tests.extend([
            "lib_{}_test".format(explicit_stamp_test_name),
            "test_{}_test".format(explicit_stamp_test_name),
            "bin_{}_test".format(explicit_stamp_test_name),
            "lib_{}_test".format(stamp_build_flag_test_name),
            "test_{}_test".format(stamp_build_flag_test_name),
            "bin_{}_test".format(stamp_build_flag_test_name),
        ])

    native.test_suite(
        name = name,
        tests = tests,
    )
