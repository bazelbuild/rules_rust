"""Tests that rust_test outputs have predictable names and paths.

Verifies that rust_test binaries are placed in the same directory as the
package (not in a test-{hash} subdirectory) and that their filenames match
the target label name. This applies to both the srcs and crate attr paths.
"""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//rust:defs.bzl", "rust_binary", "rust_common", "rust_library", "rust_test")

def _rust_test_outputs_test(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    output = tut[rust_common.crate_info].output

    # Check compilation output is in directory with same name as package
    asserts.true(env, output.dirname.split("/")[-1] == tut.label.package.split("/")[-1])

    # Check compilation output has same name as the target label
    output_filename_without_ext = paths.split_extension(output.basename)[0]
    asserts.true(env, output_filename_without_ext == tut.label.name)

    return analysistest.end(env)

rust_test_outputs_test = analysistest.make(
    _rust_test_outputs_test,
)

def _rust_test_outputs_targets():
    rust_binary(
        name = "bin_outputs",
        srcs = ["foo.rs"],
        edition = "2018",
    )

    rust_library(
        name = "lib_outputs",
        srcs = ["foo.rs"],
        edition = "2018",
    )

    rust_test(
        name = "test_outputs_with_srcs",
        srcs = ["foo.rs"],
        edition = "2018",
    )

    rust_test_outputs_test(
        name = "rust_test_outputs_using_srcs_attr",
        target_under_test = ":test_outputs_with_srcs",
    )

    rust_test(
        name = "test_outputs_with_crate_from_bin",
        crate = "bin_outputs",
        edition = "2018",
    )

    rust_test_outputs_test(
        name = "rust_test_outputs_using_crate_attr_from_bin",
        target_under_test = ":test_outputs_with_crate_from_bin",
    )

    rust_test(
        name = "test_outputs_with_crate_from_lib",
        crate = "lib_outputs",
        edition = "2018",
    )

    rust_test_outputs_test(
        name = "rust_test_outputs_using_crate_attr_from_lib",
        target_under_test = ":test_outputs_with_crate_from_lib",
    )

def rust_test_outputs_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """

    _rust_test_outputs_targets()

    native.test_suite(
        name = name,
        tests = [
            ":rust_test_outputs_using_srcs_attr",
            ":rust_test_outputs_using_crate_attr_from_bin",
            ":rust_test_outputs_using_crate_attr_from_lib",
        ],
    )
