"""Tests that rust_test targets receive codegen disambiguation flags.

rust_test targets pass --codegen=metadata and --codegen=extra-filename to rustc
so that intermediate compilation artifacts (such as .o files) get unique names. This
prevents collisions with rust_binary or rust_library targets that share the same
crate name, which would otherwise cause link failures on non-sandboxed builds
(e.g. Windows or --spawn_strategy=standalone). See
https://github.com/bazelbuild/rules_rust/pull/1434 for the original issue.

rustc flag documentation:
  https://doc.rust-lang.org/rustc/codegen-options/index.html#metadata
  https://doc.rust-lang.org/rustc/codegen-options/index.html#extra-filename
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest")
load("//rust:defs.bzl", "rust_binary", "rust_library", "rust_test")
load("//test/unit:common.bzl", "assert_argv_contains_prefix")

def _codegen_disambiguation_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    assert_argv_contains_prefix(env, tut.actions[0], "--codegen=metadata=-")
    assert_argv_contains_prefix(env, tut.actions[0], "--codegen=extra-filename=-")
    return analysistest.end(env)

codegen_disambiguation_test = analysistest.make(
    _codegen_disambiguation_test_impl,
)

def _codegen_disambiguation_targets():
    rust_binary(
        name = "my_binary",
        srcs = ["foo.rs"],
        edition = "2018",
    )

    rust_library(
        name = "my_library",
        srcs = ["foo.rs"],
        edition = "2018",
    )

    rust_test(
        name = "my_test_with_srcs",
        srcs = ["foo.rs"],
        edition = "2018",
    )

    codegen_disambiguation_test(
        name = "rust_test_srcs_codegen_disambiguation_test",
        target_under_test = ":my_test_with_srcs",
    )

    rust_test(
        name = "my_test_with_crate_from_bin",
        crate = "my_binary",
        edition = "2018",
    )

    codegen_disambiguation_test(
        name = "rust_test_crate_from_bin_codegen_disambiguation_test",
        target_under_test = ":my_test_with_crate_from_bin",
    )

    rust_test(
        name = "my_test_with_crate_from_lib",
        crate = "my_library",
        edition = "2018",
    )

    codegen_disambiguation_test(
        name = "rust_test_crate_from_lib_codegen_disambiguation_test",
        target_under_test = ":my_test_with_crate_from_lib",
    )

def codegen_disambiguation_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """

    _codegen_disambiguation_targets()

    native.test_suite(
        name = name,
        tests = [
            ":rust_test_srcs_codegen_disambiguation_test",
            ":rust_test_crate_from_bin_codegen_disambiguation_test",
            ":rust_test_crate_from_lib_codegen_disambiguation_test",
        ],
    )
