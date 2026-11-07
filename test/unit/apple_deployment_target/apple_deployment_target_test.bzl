"""Unittests for the Apple deployment target rustc actions derive from linker args."""

load("@rules_testing//lib:analysis_test.bzl", "analysis_test", "test_suite")
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

def _with_link_settings_transition_impl(_settings, attr):
    return {
        "//command_line_option:action_env": attr.action_env,
        "//command_line_option:linkopt": attr.linkopts,
    }

with_link_settings_transition = transition(
    implementation = _with_link_settings_transition_impl,
    inputs = [],
    outputs = [
        "//command_line_option:action_env",
        "//command_line_option:linkopt",
    ],
)

DepActionsInfo = provider(
    "Contains information about dependencies actions.",
    fields = {"actions": "List[Action]"},
)

def _with_link_settings_impl(ctx):
    # Only the actions are forwarded. The `-target` flag under test is not one
    # every host linker accepts, and `bazel coverage` builds the runfiles of a
    # test's dependencies, so the transitioned binary must never be linked.
    return [
        DepActionsInfo(actions = ctx.attr.target[0].actions),
        # Without this, coverage walks every dependency attribute for
        # instrumented files and builds the transitioned binary after all.
        coverage_common.instrumented_files_info(ctx, dependency_attributes = []),
    ]

with_link_settings = rule(
    implementation = _with_link_settings_impl,
    attrs = {
        "action_env": attr.string_list(),
        "linkopts": attr.string_list(),
        "target": attr.label(cfg = with_link_settings_transition),
    },
)

def _rustc_action(env, target):
    actions = [action for action in target[DepActionsInfo].actions if action.mnemonic == "Rustc"]
    env.expect.that_collection(actions).has_size(1)
    return actions[0]

def _deployment_target_from_linkopt_test(name):
    rust_binary(
        name = name + "_bin",
        srcs = ["main.rs"],
        edition = "2021",
        tags = ["manual", "nobuild"],
    )
    with_link_settings(
        name = name + "_bin_with_macos_target",
        linkopts = _MACOS_TARGET_LINKOPT,
        tags = ["manual"],
        target = name + "_bin",
    )
    analysis_test(
        name = name,
        target = name + "_bin_with_macos_target",
        impl = _deployment_target_from_linkopt_test_impl,
    )

def _deployment_target_from_linkopt_test_impl(env, target):
    rustc_action = _rustc_action(env, target)
    env.expect.that_action(rustc_action).env().contains_at_least(
        {"MACOSX_DEPLOYMENT_TARGET": "26.0"},
    )

def _no_deployment_target_without_apple_target_test(name):
    rust_binary(
        name = name + "_bin",
        srcs = ["main.rs"],
        edition = "2021",
        tags = ["manual", "nobuild"],
    )
    with_link_settings(
        name = name + "_bin_with_linux_target",
        linkopts = ["-target", "x86_64-unknown-linux-gnu"],
        tags = ["manual"],
        target = name + "_bin",
        target_compatible_with = NOT_MACOS,
    )
    analysis_test(
        name = name,
        target = name + "_bin_with_linux_target",
        impl = _no_deployment_target_without_apple_target_test_impl,
    )

def _no_deployment_target_without_apple_target_test_impl(env, target):
    rustc_action = _rustc_action(env, target)
    env.expect.that_action(rustc_action).env().keys().contains_none_of(["MACOSX_DEPLOYMENT_TARGET"])

def _rustc_env_deployment_target_wins_test(name):
    rust_binary(
        name = name + "_bin_with_rustc_env",
        srcs = ["main.rs"],
        edition = "2021",
        rustc_env = {"MACOSX_DEPLOYMENT_TARGET": "15.0"},
        tags = ["manual", "nobuild"],
    )
    with_link_settings(
        name = name + "_bin_with_rustc_env_and_macos_target",
        linkopts = _MACOS_TARGET_LINKOPT,
        tags = ["manual"],
        target = name + "_bin_with_rustc_env",
    )
    analysis_test(
        name = name,
        target = name + "_bin_with_rustc_env_and_macos_target",
        impl = _rustc_env_deployment_target_wins_test_impl,
    )

def _rustc_env_deployment_target_wins_test_impl(env, target):
    rustc_action = _rustc_action(env, target)
    env.expect.that_action(rustc_action).env().contains_at_least(
        {"MACOSX_DEPLOYMENT_TARGET": "15.0"},
    )

def _action_env_deployment_target_wins_test(name):
    rust_binary(
        name = name + "_bin",
        srcs = ["main.rs"],
        edition = "2021",
        tags = ["manual", "nobuild"],
    )
    with_link_settings(
        name = name + "_bin_with_action_env_and_macos_target",
        action_env = ["MACOSX_DEPLOYMENT_TARGET=15.0"],
        linkopts = _MACOS_TARGET_LINKOPT,
        tags = ["manual"],
        target = name + "_bin",
    )
    analysis_test(
        name = name,
        target = name + "_bin_with_action_env_and_macos_target",
        impl = _action_env_deployment_target_wins_test_impl,
    )

def _action_env_deployment_target_wins_test_impl(env, target):
    rustc_action = _rustc_action(env, target)
    env.expect.that_action(rustc_action).env().contains_at_least(
        {"MACOSX_DEPLOYMENT_TARGET": "15.0"},
    )

def _apple_deployment_target_env_test(name):
    # We don't actually need a target here, but analysis_test requires one.
    rust_binary(
        name = name + "_dummy",
        srcs = ["main.rs"],
        edition = "2021",
        tags = ["manual", "nobuild"],
    )
    analysis_test(
        name = name,
        target = name + "_dummy",
        impl = _apple_deployment_target_env_test_impl,
    )

def _apple_deployment_target_env_test_impl(env, target):
    env.expect.that_dict(apple_deployment_target_env(["-target", "arm64-apple-macosx26.0"])).contains_exactly({"MACOSX_DEPLOYMENT_TARGET": "26.0"})
    env.expect.that_dict(apple_deployment_target_env(["--target=arm64-apple-macos14.0"])).contains_exactly({"MACOSX_DEPLOYMENT_TARGET": "14.0"})
    env.expect.that_dict(apple_deployment_target_env(["-target", "arm64-apple-ios17.0"])).contains_exactly({"IPHONEOS_DEPLOYMENT_TARGET": "17.0"})
    env.expect.that_dict(apple_deployment_target_env(["-target", "arm64-apple-ios17.0-simulator"])).contains_exactly({"IPHONEOS_DEPLOYMENT_TARGET": "17.0"})
    env.expect.that_dict(apple_deployment_target_env(["-target", "arm64-apple-ios17.0-macabi"])).contains_exactly({"IPHONEOS_DEPLOYMENT_TARGET": "17.0"})
    env.expect.that_dict(apple_deployment_target_env(["-target", "arm64-apple-tvos17.0"])).contains_exactly({"TVOS_DEPLOYMENT_TARGET": "17.0"})
    env.expect.that_dict(apple_deployment_target_env(["-target", "arm64_32-apple-watchos10.0"])).contains_exactly({"WATCHOS_DEPLOYMENT_TARGET": "10.0"})
    env.expect.that_dict(apple_deployment_target_env(["-target", "arm64-apple-xros2.0"])).contains_exactly({"XROS_DEPLOYMENT_TARGET": "2.0"})
    env.expect.that_dict(apple_deployment_target_env(["-target", "arm64-apple-visionos2.0-simulator"])).contains_exactly({"XROS_DEPLOYMENT_TARGET": "2.0"})

    # The version-min flag is used when no target triple carries a version.
    env.expect.that_dict(apple_deployment_target_env(["-mmacosx-version-min=13.0"])).contains_exactly({"MACOSX_DEPLOYMENT_TARGET": "13.0"})
    env.expect.that_dict(apple_deployment_target_env(["-mios-simulator-version-min=16.0"])).contains_exactly({"IPHONEOS_DEPLOYMENT_TARGET": "16.0"})
    env.expect.that_dict(apple_deployment_target_env(["-target", "arm64-apple-macosx", "-mmacosx-version-min=13.0"])).contains_exactly({"MACOSX_DEPLOYMENT_TARGET": "13.0"})

    # A versioned triple wins over the version-min flag, and the last triple wins.
    env.expect.that_dict(apple_deployment_target_env(["-mmacosx-version-min=11.0", "-target", "arm64-apple-macosx26.0"])).contains_exactly({"MACOSX_DEPLOYMENT_TARGET": "26.0"})
    env.expect.that_dict(apple_deployment_target_env(["-target", "arm64-apple-macosx13.0", "-target", "arm64-apple-macosx26.0"])).contains_exactly({"MACOSX_DEPLOYMENT_TARGET": "26.0"})

    # Nothing to derive: no version, no Apple OS, or no target at all.
    env.expect.that_dict(apple_deployment_target_env(["-target", "arm64-apple-macosx"])).contains_exactly({})
    env.expect.that_dict(apple_deployment_target_env(["-target", "arm64-apple-darwin23"])).contains_exactly({})
    env.expect.that_dict(apple_deployment_target_env(["-target", "x86_64-unknown-linux-gnu", "-lfoo"])).contains_exactly({})
    env.expect.that_dict(apple_deployment_target_env(["-target"])).contains_exactly({})
    env.expect.that_dict(apple_deployment_target_env([])).contains_exactly({})

def apple_deployment_target_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name (str): Name of the macro.
    """
    test_suite(
        name = name,
        tests = [
            _deployment_target_from_linkopt_test,
            _no_deployment_target_without_apple_target_test,
            _rustc_env_deployment_target_wins_test,
            _action_env_deployment_target_wins_test,
            _apple_deployment_target_env_test,
        ],
    )
