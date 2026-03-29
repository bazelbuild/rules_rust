"""Analysis tests for cargo_build_info rule."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest")
load("//cargo:defs.bzl", "cargo_build_info")
load("//rust:defs.bzl", "rust_library")
load("//test/unit:common.bzl", "assert_action_mnemonic", "assert_argv_contains", "assert_list_contains")

def _rustc_env_and_flags_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    action = tut.actions[0]
    assert_action_mnemonic(env, action, "CargoBuildInfo")
    assert_argv_contains(env, action, "--rustc_env=MY_VAR=my_value")
    assert_argv_contains(env, action, "--rustc_flag=--cfg=my_feature")
    return analysistest.end(env)

rustc_env_and_flags_test = analysistest.make(_rustc_env_and_flags_test_impl)

def _build_info_propagated_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    action = tut.actions[0]
    assert_action_mnemonic(env, action, "Rustc")
    input_basenames = [f.basename for f in action.inputs.to_list()]
    assert_list_contains(env, input_basenames, "build_info.env")
    assert_list_contains(env, input_basenames, "build_info.flags")
    assert_list_contains(env, input_basenames, "build_info.out_dir")
    return analysistest.end(env)

build_info_propagated_test = analysistest.make(_build_info_propagated_test_impl)

def _cargo_build_info_tests():
    cargo_build_info(
        name = "build_info",
        rustc_env = {"MY_VAR": "my_value"},
        rustc_flags = ["--cfg=my_feature"],
    )

    rust_library(
        name = "consuming_lib",
        srcs = ["lib.rs"],
        edition = "2021",
        deps = [":build_info"],
    )

    rustc_env_and_flags_test(
        name = "rustc_env_and_flags_test",
        target_under_test = ":build_info",
    )

    build_info_propagated_test(
        name = "build_info_propagated_test",
        target_under_test = ":consuming_lib",
    )

def cargo_build_info_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """
    _cargo_build_info_tests()

    native.test_suite(
        name = name,
        tests = [
            ":rustc_env_and_flags_test",
            ":build_info_propagated_test",
        ],
    )
