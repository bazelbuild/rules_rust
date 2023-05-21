"""End to end tests for rust toolchains."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//rust:defs.bzl", "rust_library")
load("//rust:toolchain.bzl", "rust_stdlib_filegroup", "rust_toolchain")

EXEC_TOOLCHAIN_FLAG = "missing"
TOOLCHAIN_FLAG = "before"
CONFIG_FLAG = "after"

def _toolchain_adds_rustc_flags_impl(ctx):
    """ Tests adding extra_rustc_flags on the toolchain, asserts that:

    - extra_rustc_flags added by the toolchain are applied BEFORE flags added by a config on the commandline
    - The exec flags from the toolchain don't go on the commandline for a non-exec target
    """
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    action = target[DepActionsInfo].actions[0]

    asserts.equals(env, "Rustc", action.mnemonic)

    asserts.true(
        env,
        action.argv[-2:] == [TOOLCHAIN_FLAG, CONFIG_FLAG],
        "Unexpected rustc flags: {}\nShould have ended with: {}".format(
            action.argv,
            [TOOLCHAIN_FLAG, CONFIG_FLAG],
        ),
    )

    asserts.true(
        env,
        EXEC_TOOLCHAIN_FLAG not in action.argv,
        "Found exec toolchain flag ({}) in rustc flags: {}".format(EXEC_TOOLCHAIN_FLAG, action.argv),
    )

    return analysistest.end(env)

toolchain_adds_rustc_flags_test = analysistest.make(
    _toolchain_adds_rustc_flags_impl,
    config_settings = {
        "@//:extra_rustc_flags": [CONFIG_FLAG],
    },
)

def _extra_toolchain_transition_impl(settings, _attr):
    return {"//command_line_option:extra_toolchains": [
        "@rules_rust//test/toolchain:extra_flags_toolchain",
    ] + settings["//command_line_option:extra_toolchains"]}

_extra_toolchain_transition = transition(
    implementation = _extra_toolchain_transition_impl,
    inputs = ["//command_line_option:extra_toolchains"],
    outputs = ["//command_line_option:extra_toolchains"],
)

DepActionsInfo = provider(
    "Contains information about dependencies actions.",
    fields = {"actions": "List[Action]"},
)

def _collect_dep_actions_aspect_impl(target, ctx):
    actions = []
    actions.extend(target.actions)
    for dep in ctx.rule.attr.deps:
        actions.extend(dep[DepActionsInfo].actions)
    return [DepActionsInfo(actions = actions)]

collect_dep_actions_aspect = aspect(
    implementation = _collect_dep_actions_aspect_impl,
    attr_aspects = ["deps"],
)

def _extra_toolchain_wrapper_impl(ctx):
    return [ctx.attr.dep[DepActionsInfo]]

extra_toolchain_wrapper = rule(
    implementation = _extra_toolchain_wrapper_impl,
    attrs = {
        "dep": attr.label(aspects = [collect_dep_actions_aspect]),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
    cfg = _extra_toolchain_transition,
)

def _define_targets():
    rust_library(
        name = "lib",
        srcs = ["lib.rs"],
        edition = "2021",
    )

    native.filegroup(
        name = "stdlib_srcs",
        srcs = ["config.txt"],
    )
    rust_stdlib_filegroup(
        name = "std_libs",
        srcs = [":stdlib_srcs"],
    )
    write_file(
        name = "mock_rustc",
        out = "mock_rustc.exe",
        content = [],
        is_executable = True,
    )
    write_file(
        name = "mock_rustdoc",
        out = "mock_rustdoc.exe",
        content = [],
        is_executable = True,
    )

    rust_toolchain(
        name = "rust_extra_flags_toolchain",
        binary_ext = "",
        dylib_ext = ".so",
        exec_triple = "x86_64-unknown-none",
        target_triple = "x86_64-unknown-none",
        rust_doc = ":mock_rustdoc",
        rust_std = ":std_libs",
        rustc = ":mock_rustc",
        staticlib_ext = ".a",
        stdlib_linkflags = [],
        extra_rustc_flags = [TOOLCHAIN_FLAG],
        extra_exec_rustc_flags = [EXEC_TOOLCHAIN_FLAG],
        visibility = ["//visibility:public"],
    )

    native.toolchain(
        name = "extra_flags_toolchain",
        toolchain = ":rust_extra_flags_toolchain",
        toolchain_type = "@rules_rust//rust:toolchain",
    )

    extra_toolchain_wrapper(
        name = "lib_with_extra_toolchain",
        dep = ":lib",
    )

def _rust_stdlib_filegroup_provides_runfiles_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    runfiles = target[DefaultInfo].default_runfiles
    asserts.true(env, len(runfiles.files.to_list()) > 0)

    return analysistest.end(env)

rust_stdlib_filegroup_provides_runfiles_test = analysistest.make(
    _rust_stdlib_filegroup_provides_runfiles_test_impl,
)

def toolchain_test_suite(name):
    _define_targets()

    toolchain_adds_rustc_flags_test(
        name = "toolchain_adds_rustc_flags_test",
        target_under_test = ":lib_with_extra_toolchain",
    )

    rust_stdlib_filegroup_provides_runfiles_test(
        name = "rust_stdlib_filegroup_provides_runfiles_test",
        target_under_test = ":std_libs",
    )

    native.test_suite(
        name = name,
        tests = [
            ":toolchain_adds_rustc_flags_test",
            ":rust_stdlib_filegroup_provides_runfiles_test",
        ],
    )
