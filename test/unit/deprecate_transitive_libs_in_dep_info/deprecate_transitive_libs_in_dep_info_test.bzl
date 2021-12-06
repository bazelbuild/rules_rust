"""Unittests for rust rules."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//rust:defs.bzl", "rust_common", "rust_library")

def _transitive_libs_in_dep_info_not_deprecated_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    transitive_libs = tut[rust_common.dep_info].transitive_libs.to_list()

    asserts.true(
        env,
        len(transitive_libs) > 0,
        "Expected DepInfo.transitive_libs to not be empty",
    )

    return analysistest.end(env)

def _transitive_libs_in_dep_info_deprecated_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    transitive_libs = tut[rust_common.dep_info].transitive_libs.to_list()

    asserts.true(
        env,
        len(transitive_libs) == 0,
        "Expected DepInfo.transitive_libs to be empty, got {}".format(transitive_libs),
    )

    return analysistest.end(env)

transitive_libs_in_dep_info_not_deprecated_test = analysistest.make(
    _transitive_libs_in_dep_info_not_deprecated_impl,
    config_settings = {
        "//rust/settings:incompatible_remove_transitive_libs_from_dep_info": False,
    },
)

transitive_libs_in_dep_info_deprecated_test = analysistest.make(
    _transitive_libs_in_dep_info_deprecated_impl,
    config_settings = {
        "//rust/settings:incompatible_remove_transitive_libs_from_dep_info": True,
    },
)

def _transitive_libs_in_dep_info_test():
    rust_library(
        name = "foo",
        srcs = ["foo.rs"],
        deps = [":bar"],
    )

    rust_library(
        name = "bar",
        srcs = ["bar.rs"],
    )

    transitive_libs_in_dep_info_not_deprecated_test(
        name = "transitive_libs_in_dep_info_not_deprecated_test",
        target_under_test = ":foo",
    )

    transitive_libs_in_dep_info_deprecated_test(
        name = "transitive_libs_in_dep_info_deprecated_test",
        target_under_test = ":foo",
    )

def deprecate_transitive_libs_in_dep_info_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """
    _transitive_libs_in_dep_info_test()

    native.test_suite(
        name = name,
        tests = [
            ":transitive_libs_in_dep_info_not_deprecated_test",
            ":transitive_libs_in_dep_info_deprecated_test",
        ],
    )
