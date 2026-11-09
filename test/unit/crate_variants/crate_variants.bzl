"""Unittests for rust rules."""

load("@rules_testing//lib:analysis_test.bzl", "analysis_test", "test_suite")
load("@rules_testing//lib:util.bzl", "util")
load("//rust:defs.bzl", "rust_common", "rust_library")

def _crate_variants_test_impl(env, target):
    transitive_crate_outputs = target[rust_common.dep_info].transitive_crate_outputs.to_list()

    # Both variants of "foo" occur as dependencies.
    env.expect.that_int(len(transitive_crate_outputs)).equals(2)

def _crate_variants_test(name):
    util.helper_target(
        rust_library,
        name = name + "_foo",
        srcs = ["foo.rs"],
        edition = "2018",
    )

    util.helper_target(
        rust_library,
        name = name + "_foo2",
        crate_name = name + "_foo",
        srcs = ["foo.rs"],
        edition = "2018",
    )

    util.helper_target(
        rust_library,
        name = name + "_bar",
        srcs = ["bar.rs"],
        edition = "2018",
        deps = [
            ":" + name + "_foo",
            ":" + name + "_foo2",
        ],
    )

    analysis_test(
        name = name,
        target = ":" + name + "_bar",
        impl = _crate_variants_test_impl,
    )

def crate_variants_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """
    test_suite(
        name = name,
        tests = [
            _crate_variants_test,
        ],
    )
