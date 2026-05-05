"""Analysis tests verifying remap_path_prefix flags."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//rust:defs.bzl", "rust_binary", "rust_library")
load(
    "//test/unit:common.bzl",
    "assert_action_mnemonic",
    "assert_argv_contains",
    "assert_argv_contains_prefix_suffix",
    "assert_list_contains_adjacent_elements",
)

def _remap_path_prefix_source_test_impl(ctx):
    """Verify remap flags for targets with plain source files."""
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    action = target.actions[0]
    assert_action_mnemonic(env, action, "Rustc")

    assert_argv_contains(env, action, "--remap-path-prefix=${pwd}=.")
    assert_argv_contains(env, action, "--remap-path-prefix=${exec_root}=.")
    assert_argv_contains(env, action, "--remap-path-prefix=${output_base}=.")

    return analysistest.end(env)

_remap_path_prefix_source_test = analysistest.make(_remap_path_prefix_source_test_impl)

def _remap_path_prefix_generated_test_impl(ctx):
    """Verify remap flags for targets with generated sources (symlinked into bin dir)."""
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    action = target.actions[0]
    assert_action_mnemonic(env, action, "Rustc")

    assert_argv_contains_prefix_suffix(env, action, "--remap-path-prefix=${pwd}/bazel-out/", "/bin=.")
    assert_argv_contains_prefix_suffix(env, action, "--remap-path-prefix=${exec_root}/bazel-out/", "/bin=.")
    assert_argv_contains(env, action, "--remap-path-prefix=${output_base}=.")

    return analysistest.end(env)

_remap_path_prefix_generated_test = analysistest.make(_remap_path_prefix_generated_test_impl)

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

    # Targets with generated sources (write_file produces non-source files,
    # triggering transform_sources which symlinks into bin dir).
    write_file(
        name = "remap_lib_generated_src",
        out = "remap_lib_generated.rs",
        content = [
            "pub fn hello() {}",
            "",
        ],
    )

    rust_library(
        name = "remap_lib_generated",
        srcs = [":remap_lib_generated.rs"],
        edition = "2021",
    )

    write_file(
        name = "remap_bin_generated_src",
        out = "remap_bin_generated.rs",
        content = [
            "fn main() {}",
            "",
        ],
    )

    rust_binary(
        name = "remap_bin_generated",
        srcs = [":remap_bin_generated.rs"],
        edition = "2021",
    )

    # Tests for plain source files (using existing dep.rs from the package).
    _remap_path_prefix_source_test(
        name = "remap_path_prefix_source_lib_test",
        target_under_test = ":dep",
    )

    # Tests for generated sources (symlinked into bin dir).
    _remap_path_prefix_generated_test(
        name = "remap_path_prefix_generated_lib_test",
        target_under_test = ":remap_lib_generated",
    )

    _remap_path_prefix_generated_test(
        name = "remap_path_prefix_generated_bin_test",
        target_under_test = ":remap_bin_generated",
    )

    _subst_flags_test(
        name = "subst_flags_lib_test",
        target_under_test = ":remap_lib_generated",
    )

    _subst_flags_test(
        name = "subst_flags_bin_test",
        target_under_test = ":remap_bin_generated",
    )

    tests = [
        ":remap_path_prefix_source_lib_test",
        ":remap_path_prefix_generated_lib_test",
        ":remap_path_prefix_generated_bin_test",
        ":subst_flags_lib_test",
        ":subst_flags_bin_test",
    ]

    native.test_suite(
        name = name,
        tests = tests,
    )
