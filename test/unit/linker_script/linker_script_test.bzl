"""Unittests for using a linker script"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//rust:defs.bzl", "rust_binary", "rust_shared_library")
load("//test/unit:common.bzl", "assert_argv_contains")

def _linker_script_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    link_action = [action for action in tut.actions if action.mnemonic == "Rustc"][0]

    asserts.true(env, _contains_input(link_action.inputs, "linker_script.lds"))
    assert_argv_contains(env, link_action, "--codegen=link-arg=-Ttest/unit/linker_script/linker_script.lds")

    return analysistest.end(env)

linker_script_test = analysistest.make(
    _linker_script_test_impl,
)

def _contains_input(inputs, name):
    for input in inputs.to_list():
        if input.basename == name:
            return True
    return False

def _linker_script_test_target():
    rust_binary(
        name = "linker_script_bin",
        srcs = ["main.rs"],
        linker_script = ":linker_script.lds",
        edition = "2021",
        target_compatible_with = [
            "@platforms//os:linux",
        ],
    )
    rust_shared_library(
        name = "linker_script_so",
        srcs = ["lib.rs"],
        edition = "2021",
        linker_script = ":linker_script.lds",
        target_compatible_with = [
            "@platforms//os:linux",
        ],
    )
    linker_script_test(
        name = "linker_script_bin_test",
        target_under_test = "//test/unit/linker_script:linker_script_bin",
    )
    linker_script_test(
        name = "linker_script_so_test",
        target_under_test = "//test/unit/linker_script:linker_script_so",
    )

def linker_script_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """
    _linker_script_test_target()

    native.test_suite(
        name = name,
        tests = [
            ":linker_script_bin_test",
            ":linker_script_so_test",
        ],
    )
