"""Unittest to verify properties of clippy rules"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest")
load("//rust:defs.bzl", "rust_clippy_aspect")
load("//test/unit:common.bzl", "assert_argv_contains", "assert_list_contains_adjacent_elements")

def _find_clippy_action(actions):
    for action in actions:
        if action.mnemonic == "Clippy":
            return action
    fail("Failed to find Clippy action")

def _clippy_aspect_action_has_flag_impl(ctx, flags):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    clippy_action = _find_clippy_action(target.actions)

    # Ensure each flag is present in the clippy action
    for flag in flags:
        assert_argv_contains(
            env,
            clippy_action,
            flag,
        )

    clippy_checks = target[OutputGroupInfo].clippy_checks.to_list()
    if len(clippy_checks) != 1:
        fail("clippy_checks is only expected to contain 1 file")

    # Ensure the arguments to generate the marker file are present in
    # the clippy action
    assert_list_contains_adjacent_elements(
        env,
        clippy_action.argv,
        [
            "--touch-file",
            clippy_checks[0].path,
        ],
    )

    return analysistest.end(env)

def _binary_clippy_aspect_action_has_warnings_flag_test_impl(ctx):
    return _clippy_aspect_action_has_flag_impl(
        ctx,
        ["-Dwarnings"],
    )

def _library_clippy_aspect_action_has_warnings_flag_test_impl(ctx):
    return _clippy_aspect_action_has_flag_impl(
        ctx,
        ["-Dwarnings"],
    )

def _test_clippy_aspect_action_has_warnings_flag_test_impl(ctx):
    return _clippy_aspect_action_has_flag_impl(
        ctx,
        [
            "-Dwarnings",
            "--test",
        ],
    )

def make_clippy_aspect_unittest(impl):
    return analysistest.make(
        impl,
        extra_target_under_test_aspects = [rust_clippy_aspect],
    )

binary_clippy_aspect_action_has_warnings_flag_test = make_clippy_aspect_unittest(_binary_clippy_aspect_action_has_warnings_flag_test_impl)
library_clippy_aspect_action_has_warnings_flag_test = make_clippy_aspect_unittest(_library_clippy_aspect_action_has_warnings_flag_test_impl)
test_clippy_aspect_action_has_warnings_flag_test = make_clippy_aspect_unittest(_test_clippy_aspect_action_has_warnings_flag_test_impl)

def clippy_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name (str): Name of the macro.
    """

    binary_clippy_aspect_action_has_warnings_flag_test(
        name = "binary_clippy_aspect_action_has_warnings_flag_test",
        target_under_test = Label("//test/clippy:ok_binary"),
    )
    library_clippy_aspect_action_has_warnings_flag_test(
        name = "library_clippy_aspect_action_has_warnings_flag_test",
        target_under_test = Label("//test/clippy:ok_library"),
    )
    test_clippy_aspect_action_has_warnings_flag_test(
        name = "test_clippy_aspect_action_has_warnings_flag_test",
        target_under_test = Label("//test/clippy:ok_test"),
    )

    native.test_suite(
        name = name,
        tests = [
            ":binary_clippy_aspect_action_has_warnings_flag_test",
            ":library_clippy_aspect_action_has_warnings_flag_test",
            ":test_clippy_aspect_action_has_warnings_flag_test",
        ],
    )
