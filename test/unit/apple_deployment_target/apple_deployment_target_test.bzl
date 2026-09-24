"""Unittests for the Apple deployment target rustc actions derive from linker args."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts", "unittest")
load("//rust:defs.bzl", "rust_binary")

# buildifier: disable=bzl-visibility
load("//rust/private:rustc.bzl", "apple_deployment_target_env")
load("//test/unit:common.bzl", "assert_env_value")

_MACOS_TARGET_LINKOPT = ["-target", "arm64-apple-macosx26.0"]

# The Apple cc_toolchain appends its own `-target` triple after the user's link
# flags, so on macOS the last triple in the link args is the toolchain's rather
# than the one passed through `--linkopt`. Tests that pin the derived value to
# the `--linkopt` triple only hold on other hosts.
NOT_MACOS = select({
    "@platforms//os:macos": ["@platforms//:incompatible"],
    "//conditions:default": [],
})

def _rustc_action(env):
    target = analysistest.target_under_test(env)
    actions = [action for action in target.actions if action.mnemonic == "Rustc"]
    asserts.equals(env, 1, len(actions))
    return actions[0]

def _deployment_target_from_linkopt_test_impl(ctx):
    env = analysistest.begin(ctx)
    assert_env_value(env, _rustc_action(env), "MACOSX_DEPLOYMENT_TARGET", "26.0")
    return analysistest.end(env)

def _no_deployment_target_without_apple_target_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.false(env, "MACOSX_DEPLOYMENT_TARGET" in _rustc_action(env).env)
    return analysistest.end(env)

def _user_deployment_target_wins_test_impl(ctx):
    env = analysistest.begin(ctx)
    assert_env_value(env, _rustc_action(env), "MACOSX_DEPLOYMENT_TARGET", "15.0")
    return analysistest.end(env)

deployment_target_from_linkopt_test = analysistest.make(
    _deployment_target_from_linkopt_test_impl,
    config_settings = {
        "//command_line_option:linkopt": _MACOS_TARGET_LINKOPT,
    },
)

no_deployment_target_without_apple_target_test = analysistest.make(
    _no_deployment_target_without_apple_target_test_impl,
    config_settings = {
        "//command_line_option:linkopt": ["-target", "x86_64-unknown-linux-gnu"],
    },
)

rustc_env_deployment_target_wins_test = analysistest.make(
    _user_deployment_target_wins_test_impl,
    config_settings = {
        "//command_line_option:linkopt": _MACOS_TARGET_LINKOPT,
    },
)

action_env_deployment_target_wins_test = analysistest.make(
    _user_deployment_target_wins_test_impl,
    config_settings = {
        "//command_line_option:action_env": ["MACOSX_DEPLOYMENT_TARGET=15.0"],
        "//command_line_option:linkopt": _MACOS_TARGET_LINKOPT,
    },
)

def _apple_deployment_target_env_test_impl(ctx):
    env = unittest.begin(ctx)

    asserts.equals(env, {"MACOSX_DEPLOYMENT_TARGET": "26.0"}, apple_deployment_target_env(["-target", "arm64-apple-macosx26.0"]))
    asserts.equals(env, {"MACOSX_DEPLOYMENT_TARGET": "14.0"}, apple_deployment_target_env(["--target=arm64-apple-macos14.0"]))
    asserts.equals(env, {"IPHONEOS_DEPLOYMENT_TARGET": "17.0"}, apple_deployment_target_env(["-target", "arm64-apple-ios17.0"]))
    asserts.equals(env, {"IPHONEOS_DEPLOYMENT_TARGET": "17.0"}, apple_deployment_target_env(["-target", "arm64-apple-ios17.0-simulator"]))
    asserts.equals(env, {"IPHONEOS_DEPLOYMENT_TARGET": "17.0"}, apple_deployment_target_env(["-target", "arm64-apple-ios17.0-macabi"]))
    asserts.equals(env, {"TVOS_DEPLOYMENT_TARGET": "17.0"}, apple_deployment_target_env(["-target", "arm64-apple-tvos17.0"]))
    asserts.equals(env, {"WATCHOS_DEPLOYMENT_TARGET": "10.0"}, apple_deployment_target_env(["-target", "arm64_32-apple-watchos10.0"]))
    asserts.equals(env, {"XROS_DEPLOYMENT_TARGET": "2.0"}, apple_deployment_target_env(["-target", "arm64-apple-xros2.0"]))
    asserts.equals(env, {"XROS_DEPLOYMENT_TARGET": "2.0"}, apple_deployment_target_env(["-target", "arm64-apple-visionos2.0-simulator"]))

    # The version-min flag is used when no target triple carries a version.
    asserts.equals(env, {"MACOSX_DEPLOYMENT_TARGET": "13.0"}, apple_deployment_target_env(["-mmacosx-version-min=13.0"]))
    asserts.equals(env, {"IPHONEOS_DEPLOYMENT_TARGET": "16.0"}, apple_deployment_target_env(["-mios-simulator-version-min=16.0"]))
    asserts.equals(env, {"MACOSX_DEPLOYMENT_TARGET": "13.0"}, apple_deployment_target_env(["-target", "arm64-apple-macosx", "-mmacosx-version-min=13.0"]))

    # A versioned triple wins over the version-min flag, and the last triple wins.
    asserts.equals(env, {"MACOSX_DEPLOYMENT_TARGET": "26.0"}, apple_deployment_target_env(["-mmacosx-version-min=11.0", "-target", "arm64-apple-macosx26.0"]))
    asserts.equals(env, {"MACOSX_DEPLOYMENT_TARGET": "26.0"}, apple_deployment_target_env(["-target", "arm64-apple-macosx13.0", "-target", "arm64-apple-macosx26.0"]))

    # Nothing to derive: no version, no Apple OS, or no target at all.
    asserts.equals(env, {}, apple_deployment_target_env(["-target", "arm64-apple-macosx"]))
    asserts.equals(env, {}, apple_deployment_target_env(["-target", "arm64-apple-darwin23"]))
    asserts.equals(env, {}, apple_deployment_target_env(["-target", "x86_64-unknown-linux-gnu", "-lfoo"]))
    asserts.equals(env, {}, apple_deployment_target_env(["-target"]))
    asserts.equals(env, {}, apple_deployment_target_env([]))

    return unittest.end(env)

apple_deployment_target_env_test = unittest.make(_apple_deployment_target_env_test_impl)

def _define_test_targets():
    rust_binary(
        name = "bin",
        srcs = ["main.rs"],
        edition = "2021",
    )

    rust_binary(
        name = "bin_with_rustc_env",
        srcs = ["main.rs"],
        edition = "2021",
        rustc_env = {"MACOSX_DEPLOYMENT_TARGET": "15.0"},
    )

def apple_deployment_target_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name (str): Name of the macro.
    """
    _define_test_targets()

    deployment_target_from_linkopt_test(
        name = "deployment_target_from_linkopt_test",
        target_under_test = ":bin",
        target_compatible_with = NOT_MACOS,
    )

    no_deployment_target_without_apple_target_test(
        name = "no_deployment_target_without_apple_target_test",
        target_under_test = ":bin",
        target_compatible_with = NOT_MACOS,
    )

    rustc_env_deployment_target_wins_test(
        name = "rustc_env_deployment_target_wins_test",
        target_under_test = ":bin_with_rustc_env",
    )

    action_env_deployment_target_wins_test(
        name = "action_env_deployment_target_wins_test",
        target_under_test = ":bin",
    )

    apple_deployment_target_env_test(
        name = "apple_deployment_target_env_test",
    )

    native.test_suite(
        name = name,
        tests = [
            ":deployment_target_from_linkopt_test",
            ":no_deployment_target_without_apple_target_test",
            ":rustc_env_deployment_target_wins_test",
            ":action_env_deployment_target_wins_test",
            ":apple_deployment_target_env_test",
        ],
    )
