"""
Tests for handling of cc_toolchain's static_runtime_lib/dynamic_runtime_lib.
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@rules_cc//cc:action_names.bzl", "ACTION_NAMES")
load("@rules_cc//cc:cc_toolchain_config_lib.bzl", "action_config", "feature", "tool")
load("@rules_cc//cc:defs.bzl", "cc_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/toolchains:cc_toolchain_config_info.bzl", "CcToolchainConfigInfo")
load("//rust:defs.bzl", "rust_shared_library", "rust_static_library")
load("//test/unit:common.bzl", "get_bin_dir_from_action")

def _test_cc_config_impl(ctx):
    config_info = cc_common.create_cc_toolchain_config_info(
        ctx = ctx,
        toolchain_identifier = "test-cc-toolchain",
        host_system_name = "unknown",
        target_system_name = "unknown",
        target_cpu = "unknown",
        target_libc = "unknown",
        compiler = "unknown",
        abi_version = "unknown",
        abi_libc_version = "unknown",
        action_configs = [
            action_config(
                action_name = action_name,
                tools = [tool(tool = ctx.file.linker)],
            )
            for action_name in [
                ACTION_NAMES.cpp_link_dynamic_library,
                ACTION_NAMES.cpp_link_static_library,
            ]
        ],
        features = [
            feature(name = "static_link_cpp_runtimes", enabled = True),
        ],
    )
    return config_info

test_cc_config = rule(
    implementation = _test_cc_config_impl,
    attrs = {"linker": attr.label(allow_single_file = True)},
    provides = [CcToolchainConfigInfo],
)

def _with_extra_toolchain_transition_impl(_settings, attr):
    return {"//command_line_option:extra_toolchains": [attr.extra_toolchain]}

with_extra_toolchain_transition = transition(
    implementation = _with_extra_toolchain_transition_impl,
    inputs = [],
    outputs = ["//command_line_option:extra_toolchains"],
)

DepActionsInfo = provider(
    "Contains information about dependencies actions.",
    fields = {"actions": "List[Action]"},
)

def _with_extra_toolchain_impl(ctx):
    return [
        DepActionsInfo(actions = ctx.attr.target[0].actions),
    ]

with_extra_toolchain = rule(
    implementation = _with_extra_toolchain_impl,
    attrs = {
        "extra_toolchain": attr.label(),
        "target": attr.label(cfg = with_extra_toolchain_transition),
    },
)

def _inputs_analysis_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    action = tut[DepActionsInfo].actions[0]
    asserts.equals(env, action.mnemonic, "Rustc")
    inputs = action.inputs.to_list()
    for expected in ctx.attr.expected_inputs:
        asserts.true(
            env,
            any([input.path.endswith("/" + expected) for input in inputs]),
            "error: expected '{}' to be in inputs: '{}'".format(expected, inputs),
        )

    linker_files = [file for file in inputs if file.basename == "link-wrapper"]
    asserts.equals(env, 1, len(linker_files))

    linker_args = [arg for arg in action.argv if arg.startswith("--codegen=linker=")]
    asserts.equals(env, 1, len(linker_args))

    bin_dir = get_bin_dir_from_action(action)
    linker_path = "{}/{}".format(bin_dir, linker_files[0].short_path) if bin_dir == "bazel-out/cfg/bin" else linker_files[0].path
    asserts.equals(env, "--codegen=linker={}".format(linker_path), linker_args[0])

    return analysistest.end(env)

inputs_analysis_test = analysistest.make(
    impl = _inputs_analysis_test_impl,
    doc = """An analysistest to examine the inputs of a library target.""",
    attrs = {
        "expected_inputs": attr.string_list(),
    },
)

def runtime_libs_test(name):
    """Produces test shared and static library targets that are set up to use a custom cc_toolchain with custom runtime libs.

    Args:
      name: The name of the test target.
    """

    write_file(
        name = "%s/linker" % name,
        out = "%s/link-wrapper" % name,
        content = ["#!/bin/sh", "exit 0"],
        is_executable = True,
    )

    test_cc_config(
        name = "%s/cc_toolchain_config" % name,
        linker = ":%s/linker" % name,
    )
    cc_toolchain(
        name = "%s/test_cc_toolchain_impl" % name,
        all_files = ":empty",
        compiler_files = ":empty",
        dwp_files = ":empty",
        linker_files = ":%s/linker" % name,
        objcopy_files = ":empty",
        strip_files = ":empty",
        supports_param_files = 0,
        toolchain_config = ":%s/cc_toolchain_config" % name,
        toolchain_identifier = "dummy_wasm32_cc",
        static_runtime_lib = ":dummy.a",
        dynamic_runtime_lib = ":dummy.so",
    )
    native.toolchain(
        name = "%s/test_cc_toolchain" % name,
        toolchain = ":%s/test_cc_toolchain_impl" % name,
        toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
    )

    rust_shared_library(
        name = "%s/__shared_library" % name,
        edition = "2018",
        srcs = ["lib.rs"],
        tags = ["manual", "nobuild"],
    )

    with_extra_toolchain(
        name = "%s/_shared_library" % name,
        extra_toolchain = ":%s/test_cc_toolchain" % name,
        target = "%s/__shared_library" % name,
        tags = ["manual"],
    )

    inputs_analysis_test(
        name = "%s/shared_library" % name,
        target_under_test = "%s/_shared_library" % name,
        expected_inputs = ["dummy.so"],
    )

    rust_static_library(
        name = "%s/__static_library" % name,
        edition = "2018",
        srcs = ["lib.rs"],
        tags = ["manual", "nobuild"],
    )

    with_extra_toolchain(
        name = "%s/_static_library" % name,
        extra_toolchain = ":%s/test_cc_toolchain" % name,
        target = "%s/__static_library" % name,
        tags = ["manual"],
    )

    inputs_analysis_test(
        name = "%s/static_library" % name,
        target_under_test = "%s/_static_library" % name,
        expected_inputs = ["dummy.a"],
    )
