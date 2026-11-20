"""Tests that rust_test outputs have predictable names and paths.

Verifies that rust_test binaries are placed in the same directory as the
package (not in a test-{hash} subdirectory) and that their filenames match
the target label name. This applies to both the srcs and crate attr paths.
"""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test", "test_suite")
load("@rules_testing//lib:util.bzl", "util")
load("//rust:defs.bzl", "rust_binary", "rust_common", "rust_library", "rust_test")

def _rust_test_outputs_test_impl(env, target):
    output = target[rust_common.crate_info].output

    # Check compilation output is in directory with same name as package
    env.expect.that_str(output.dirname.split("/")[-1]).equals(
        target.label.package.split("/")[-1],
    )

    # Check compilation output has same name as the target label
    output_filename_without_ext = paths.split_extension(output.basename)[0]
    env.expect.that_str(output_filename_without_ext).equals(target.label.name)

def _rust_test_outputs_using_srcs_attr(name):
    util.helper_target(
        rust_test,
        name = name + "_test_outputs_with_srcs",
        srcs = ["foo.rs"],
        edition = "2018",
    )

    analysis_test(
        name = name,
        target = ":" + name + "_test_outputs_with_srcs",
        impl = _rust_test_outputs_test_impl,
    )

def _rust_test_outputs_using_crate_attr_from_bin(name):
    util.helper_target(
        rust_binary,
        name = name + "_bin_outputs",
        srcs = ["foo.rs"],
        edition = "2018",
    )

    util.helper_target(
        rust_test,
        name = name + "_test_outputs_with_crate_from_bin",
        crate = ":" + name + "_bin_outputs",
        edition = "2018",
    )

    analysis_test(
        name = name,
        target = ":" + name + "_test_outputs_with_crate_from_bin",
        impl = _rust_test_outputs_test_impl,
    )

def _rust_test_outputs_using_crate_attr_from_lib(name):
    util.helper_target(
        rust_library,
        name = name + "_lib_outputs",
        srcs = ["foo.rs"],
        edition = "2018",
    )

    util.helper_target(
        rust_test,
        name = name + "_test_outputs_with_crate_from_lib",
        crate = ":" + name + "_lib_outputs",
        edition = "2018",
    )

    analysis_test(
        name = name,
        target = ":" + name + "_test_outputs_with_crate_from_lib",
        impl = _rust_test_outputs_test_impl,
    )

def rust_test_outputs_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """
    test_suite(
        name = name,
        tests = [
            _rust_test_outputs_using_srcs_attr,
            _rust_test_outputs_using_crate_attr_from_bin,
            _rust_test_outputs_using_crate_attr_from_lib,
        ],
    )
