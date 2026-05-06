"""Analysis tests verifying remap_path_prefix flags."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//rust:defs.bzl", "rust_binary", "rust_library")
load(
    "//test/unit:common.bzl",
    "assert_action_mnemonic",
    "assert_list_contains_adjacent_elements",
)

def _remap_path_prefix_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    action = target.actions[0]
    assert_action_mnemonic(env, action, "Rustc")

    assert_list_contains_adjacent_elements(env, action.argv, [
        "--remap-path-prefix=${output_base}=.",
        "--remap-path-prefix=${pwd}=.",
        "--remap-path-prefix=${exec_root}=.",
    ])

    return analysistest.end(env)

_remap_path_prefix_test = analysistest.make(_remap_path_prefix_test_impl)

def _subst_flags_test_impl(ctx):
    """Verify that process wrapper --subst flags are present."""
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    action = target.actions[0]
    assert_action_mnemonic(env, action, "Rustc")

    assert_list_contains_adjacent_elements(env, action.argv, ["--subst", "pwd=${pwd}"])
    assert_list_contains_adjacent_elements(env, action.argv, ["--subst", "exec_root=${exec_root}"])
    assert_list_contains_adjacent_elements(env, action.argv, ["--subst", "output_base=${output_base}"])

    return analysistest.end(env)

_subst_flags_test = analysistest.make(_subst_flags_test_impl)

def remap_path_prefix_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name (str): The name of the test suite.
    """
    write_file(
        name = "remap_lib_src",
        out = "remap_lib.rs",
        content = [
            "pub fn hello() {}",
            "",
        ],
    )

    rust_library(
        name = "remap_lib",
        srcs = [":remap_lib.rs"],
        edition = "2021",
    )

    write_file(
        name = "remap_bin_src",
        out = "remap_bin.rs",
        content = [
            "fn main() {}",
            "",
        ],
    )

    rust_binary(
        name = "remap_bin",
        srcs = [":remap_bin.rs"],
        edition = "2021",
    )

    _remap_path_prefix_test(
        name = "remap_path_prefix_lib_test",
        target_under_test = ":remap_lib",
    )

    _remap_path_prefix_test(
        name = "remap_path_prefix_bin_test",
        target_under_test = ":remap_bin",
    )

    _subst_flags_test(
        name = "subst_flags_lib_test",
        target_under_test = ":remap_lib",
    )

    _subst_flags_test(
        name = "subst_flags_bin_test",
        target_under_test = ":remap_bin",
    )

    tests = [
        ":remap_path_prefix_lib_test",
        ":remap_path_prefix_bin_test",
        ":subst_flags_lib_test",
        ":subst_flags_bin_test",
    ]

    native.test_suite(
        name = name,
        tests = tests,
    )
