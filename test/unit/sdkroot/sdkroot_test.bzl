"""Tests for selecting SDKROOT for Rust compile actions."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_cc//cc:action_names.bzl", "ACTION_NAMES")
load("@rules_cc//cc:cc_toolchain_config_lib.bzl", "action_config", "env_entry", "env_set", "feature", "tool")
load("@rules_cc//cc:defs.bzl", "cc_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/toolchains:cc_toolchain_config_info.bzl", "CcToolchainConfigInfo")
load("//rust:defs.bzl", "rust_binary")
load("//test/unit:common.bzl", "assert_env_value")

_CC_SDKROOT = "cc-toolchain-sdkroot"
_FALLBACK_SDKROOT = "${pwd}/test/unit/sdkroot/fallback.sdkroot"

def _cc_toolchain_config_impl(ctx):
    features = []
    if ctx.attr.apple_sdk_platform:
        features.append(feature(
            name = "apple_sdk_platform",
            enabled = True,
            env_sets = [
                env_set(
                    actions = [ACTION_NAMES.cpp_link_executable],
                    env_entries = [
                        env_entry(
                            key = "APPLE_SDK_PLATFORM",
                            value = ctx.attr.apple_sdk_platform,
                        ),
                    ],
                ),
            ],
        ))
    if ctx.attr.sdkroot:
        features.append(feature(
            name = "sdkroot",
            enabled = True,
            env_sets = [
                env_set(
                    actions = [ACTION_NAMES.c_compile],
                    env_entries = [
                        env_entry(
                            key = "SDKROOT",
                            value = ctx.attr.sdkroot,
                        ),
                    ],
                ),
            ],
        ))

    return cc_common.create_cc_toolchain_config_info(
        ctx = ctx,
        action_configs = [
            action_config(
                action_name = ACTION_NAMES.c_compile,
                tools = [tool(path = "/usr/bin/false")],
            ),
            action_config(
                action_name = ACTION_NAMES.cpp_link_executable,
                tools = [tool(path = "/usr/bin/false")],
            ),
        ],
        features = features,
        toolchain_identifier = "sdkroot-test-toolchain",
        host_system_name = "unknown",
        target_system_name = "unknown",
        target_cpu = "unknown",
        target_libc = "unknown",
        compiler = "unknown",
        abi_version = "unknown",
        abi_libc_version = "unknown",
    )

_cc_toolchain_config = rule(
    implementation = _cc_toolchain_config_impl,
    attrs = {
        "apple_sdk_platform": attr.string(),
        "sdkroot": attr.string(),
    },
    provides = [CcToolchainConfigInfo],
)

def _extra_toolchain_transition_impl(_settings, attr):
    return {"//command_line_option:extra_toolchains": [attr.extra_toolchain]}

_extra_toolchain_transition = transition(
    implementation = _extra_toolchain_transition_impl,
    inputs = [],
    outputs = ["//command_line_option:extra_toolchains"],
)

_RustcActionsInfo = provider(fields = {"actions": "Rustc actions from rust_binary."})

def _rust_binary_with_cc_toolchain_impl(ctx):
    return [_RustcActionsInfo(actions = ctx.attr.target[0].actions)]

_rust_binary_with_cc_toolchain = rule(
    implementation = _rust_binary_with_cc_toolchain_impl,
    attrs = {
        "extra_toolchain": attr.string(),
        "target": attr.label(cfg = _extra_toolchain_transition),
    },
)

def _sdkroot_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    rustc_action = [action for action in target[_RustcActionsInfo].actions if action.mnemonic == "Rustc"][0]
    if ctx.attr.expected_sdkroot:
        assert_env_value(env, rustc_action, "SDKROOT", ctx.attr.expected_sdkroot)
    else:
        asserts.false(env, "SDKROOT" in rustc_action.env, "Expected env to not contain SDKROOT")
    return analysistest.end(env)

_sdkroot_test = analysistest.make(
    _sdkroot_test_impl,
    attrs = {
        "expected_sdkroot": attr.string(mandatory = True),
    },
)

def _sdkroot_subject(name, cc_sdkroot = "", apple_sdk_platform = ""):
    _cc_toolchain_config(
        name = name + "_cc_toolchain_config",
        apple_sdk_platform = apple_sdk_platform,
        sdkroot = cc_sdkroot,
    )
    cc_toolchain(
        name = name + "_cc_toolchain_impl",
        all_files = ":empty",
        compiler_files = ":empty",
        dwp_files = ":empty",
        linker_files = ":empty",
        objcopy_files = ":empty",
        strip_files = ":empty",
        supports_param_files = 0,
        toolchain_config = name + "_cc_toolchain_config",
        toolchain_identifier = "sdkroot-test-toolchain",
    )
    native.toolchain(
        name = name + "_cc_toolchain",
        toolchain = name + "_cc_toolchain_impl",
        toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
    )
    rust_binary(
        name = name + "_binary",
        srcs = ["main.rs"],
        macos_sdkroot = "fallback.sdkroot",
        tags = ["manual", "nobuild"],
    )
    _rust_binary_with_cc_toolchain(
        name = name + "_subject",
        extra_toolchain = "//{}:{}_cc_toolchain".format(native.package_name(), name),
        target = name + "_binary",
        tags = ["manual"],
    )

def sdkroot_test_suite(name):
    _sdkroot_subject(
        name = "cc_sdkroot",
        cc_sdkroot = _CC_SDKROOT,
    )
    _sdkroot_test(
        name = "cc_sdkroot_test",
        expected_sdkroot = _CC_SDKROOT,
        target_under_test = ":cc_sdkroot_subject",
    )

    _sdkroot_subject(
        name = "fallback_sdkroot",
        cc_sdkroot = "",
    )
    _sdkroot_test(
        name = "fallback_sdkroot_test",
        expected_sdkroot = _FALLBACK_SDKROOT,
        target_under_test = ":fallback_sdkroot_subject",
    )

    _sdkroot_subject(
        name = "apple_sdk_platform",
        apple_sdk_platform = "MacOSX",
    )
    _sdkroot_test(
        name = "apple_sdk_platform_test",
        expected_sdkroot = "",
        target_under_test = ":apple_sdk_platform_subject",
    )

    native.test_suite(
        name = name,
        tests = [
            ":apple_sdk_platform_test",
            ":cc_sdkroot_test",
            ":fallback_sdkroot_test",
        ],
    )
