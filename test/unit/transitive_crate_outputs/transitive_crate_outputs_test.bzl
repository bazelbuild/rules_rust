"""Unittests for rust rules."""

load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test", "test_suite")
load("@rules_testing//lib:util.bzl", "util")
load("//rust:defs.bzl", "rust_common", "rust_library")

def _transitive_crate_outputs_test_impl(env, target):
    transitive_crate_outputs = target[rust_common.dep_info].transitive_crate_outputs.to_list()

    # Check that the non-crate output baz.a didn't find its way into transitive_crate_outputs
    # while the bar.rlib did.
    env.expect.that_int(len(transitive_crate_outputs)).equals(1)
    env.expect.that_str(transitive_crate_outputs[0].extension).equals("rlib")

def _transitive_crate_outputs_test(name):
    util.helper_target(
        rust_library,
        name = name + "_foo",
        srcs = ["foo.rs"],
        edition = "2018",
        deps = [
            name + "_bar",
            name + "_baz",
        ],
    )

    util.helper_target(
        rust_library,
        name = name + "_bar",
        srcs = ["bar.rs"],
        edition = "2018",
    )

    # buildifier: disable=native-cc
    util.helper_target(
        cc_library,
        name = name + "_baz",
        srcs = ["baz.cc"],
    )

    analysis_test(
        name = name,
        target = name + "_foo",
        impl = _transitive_crate_outputs_test_impl,
    )

def transitive_crate_outputs_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """
    test_suite(
        name = name,
        tests = [
            _transitive_crate_outputs_test,
        ],
    )
