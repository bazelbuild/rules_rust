"""Analysis tests verifying remap_path_prefix flags."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//rust:defs.bzl", "rust_binary", "rust_library")
load(
    "//test/unit:common.bzl",
    "assert_action_mnemonic",
    "assert_argv_contains",
    "assert_argv_contains_not",
    "assert_list_contains_adjacent_elements",
    "get_bin_dir_from_action",
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

def _coverage_remap_path_prefix_test_impl(ctx):
    """Verify a single `--remap-path-prefix` flag covers the bin directory.

    The flag is derived from a `File` via `map_each` so Bazel's path
    mapping (`--experimental_output_paths=strip`) rewrites the
    `<config>` segment to `cfg` before it reaches rustc — one flag
    works for both the path-mapped and un-mapped forms.
    """
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    action = target.actions[0]
    assert_action_mnemonic(env, action, "Rustc")

    # If the host toolchain does not support coverage (no `llvm_cov` or
    # missing `profiler_builtins`) the instrument-coverage flag will be
    # absent and the remap flag is not expected either.
    if "--codegen=instrument-coverage" not in action.argv:
        return analysistest.end(env)

    bin_dir = get_bin_dir_from_action(action)
    assert_argv_contains(env, action, "--remap-path-prefix={}/=".format(bin_dir))

    return analysistest.end(env)

_coverage_remap_path_prefix_test = analysistest.make(
    _coverage_remap_path_prefix_test_impl,
    config_settings = {
        "//command_line_option:collect_code_coverage": True,
    },
)

def _no_coverage_remap_path_prefix_test_impl(ctx):
    """Verify the coverage-specific remap flag is absent without coverage."""
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    action = target.actions[0]
    assert_action_mnemonic(env, action, "Rustc")

    assert_argv_contains_not(env, action, "--codegen=instrument-coverage")

    bin_dir = get_bin_dir_from_action(action)
    assert_argv_contains_not(env, action, "--remap-path-prefix={}/=".format(bin_dir))

    return analysistest.end(env)

_no_coverage_remap_path_prefix_test = analysistest.make(
    _no_coverage_remap_path_prefix_test_impl,
    config_settings = {
        "//command_line_option:collect_code_coverage": False,
    },
)

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

    # A library whose source set contains a generated file — this is the
    # case `transform_sources` is designed for, and the one that
    # previously lost all coverage data because the records pointed at
    # `bazel-out/.../bin/...`.
    write_file(
        name = "mixed_inline_src",
        out = "mixed_inline.rs",
        content = [
            "pub fn inline() {}",
            "",
        ],
    )

    write_file(
        name = "mixed_generated_src",
        out = "mixed_generated.rs",
        content = [
            "pub fn generated() {}",
            "",
        ],
    )

    rust_library(
        name = "remap_mixed_lib",
        srcs = [
            ":mixed_inline.rs",
            ":mixed_generated_src",
        ],
        crate_root = ":mixed_inline.rs",
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

    _coverage_remap_path_prefix_test(
        name = "coverage_remap_path_prefix_mixed_lib_test",
        target_under_test = ":remap_mixed_lib",
    )

    _no_coverage_remap_path_prefix_test(
        name = "no_coverage_remap_path_prefix_lib_test",
        target_under_test = ":remap_lib",
    )

    tests = [
        ":remap_path_prefix_lib_test",
        ":remap_path_prefix_bin_test",
        ":subst_flags_lib_test",
        ":subst_flags_bin_test",
        ":coverage_remap_path_prefix_mixed_lib_test",
        ":no_coverage_remap_path_prefix_lib_test",
    ]

    native.test_suite(
        name = name,
        tests = tests,
    )
