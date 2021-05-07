"""Unit tests for crate names."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//rust:defs.bzl", "rust_binary", "rust_library", "rust_test")
load("//test/unit:common.bzl", "assert_argv_contains")

def _default_crate_name_library_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    actions = analysistest.target_actions(env)

    # Note: Hyphens in crate name converted to underscores.
    assert_argv_contains(env, actions[0], "--crate-name=default_crate_name_library")
    return analysistest.end(env)

def _custom_crate_name_library_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    actions = analysistest.target_actions(env)
    assert_argv_contains(env, actions[0], "--crate-name=custom_name")
    return analysistest.end(env)

def _default_crate_name_binary_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    actions = analysistest.target_actions(env)

    # Note: Hyphens in crate name converted to underscores.
    assert_argv_contains(env, actions[0], "--crate-name=default_crate_name_binary")
    return analysistest.end(env)

def _custom_crate_name_binary_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    actions = analysistest.target_actions(env)
    assert_argv_contains(env, actions[0], "--crate-name=custom_name")
    return analysistest.end(env)

def _default_crate_name_test_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    actions = analysistest.target_actions(env)

    # Note: Hyphens in crate name converted to underscores.
    assert_argv_contains(env, actions[0], "--crate-name=default_crate_name_test")
    return analysistest.end(env)

def _custom_crate_name_test_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    actions = analysistest.target_actions(env)
    assert_argv_contains(env, actions[0], "--crate-name=custom_name")
    return analysistest.end(env)

def _invalid_default_crate_name_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, "contains invalid character(s): /")
    return analysistest.end(env)

def _invalid_custom_crate_name_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, "contains invalid character(s): -")
    return analysistest.end(env)

default_crate_name_library_test = analysistest.make(
    _default_crate_name_library_test_impl,
)
custom_crate_name_library_test = analysistest.make(
    _custom_crate_name_library_test_impl,
)
default_crate_name_binary_test = analysistest.make(
    _default_crate_name_binary_test_impl,
)
custom_crate_name_binary_test = analysistest.make(
    _custom_crate_name_binary_test_impl,
)
default_crate_name_test_test = analysistest.make(
    _default_crate_name_test_test_impl,
)
custom_crate_name_test_test = analysistest.make(
    _custom_crate_name_test_test_impl,
)
invalid_default_crate_name_test = analysistest.make(
    _invalid_default_crate_name_test_impl,
    expect_failure = True,
)
invalid_custom_crate_name_test = analysistest.make(
    _invalid_custom_crate_name_test_impl,
    expect_failure = True,
)

def _crate_name_test():
    rust_library(
        name = "default-crate-name-library",
        srcs = ["lib.rs"],
    )

    rust_library(
        name = "custom-crate-name-library",
        crate_name = "custom_name",
        srcs = ["lib.rs"],
    )

    rust_binary(
        name = "default-crate-name-binary",
        srcs = ["main.rs"],
    )

    rust_binary(
        name = "custom-crate-name-binary",
        crate_name = "custom_name",
        srcs = ["main.rs"],
    )

    rust_test(
        name = "default-crate-name-test",
        srcs = ["main.rs"],
    )

    rust_test(
        name = "custom-crate-name-test",
        crate_name = "custom_name",
        srcs = ["main.rs"],
    )

    rust_library(
        name = "invalid/default-crate-name",
        srcs = ["lib.rs"],
        tags = ["manual", "norustfmt"],
    )

    rust_library(
        name = "invalid-custom-crate-name",
        crate_name = "hyphens-not-allowed",
        srcs = ["lib.rs"],
        tags = ["manual", "norustfmt"],
    )

    default_crate_name_library_test(
        name = "default_crate_name_library_test",
        target_under_test = ":default-crate-name-library",
    )

    custom_crate_name_library_test(
        name = "custom_crate_name_library_test",
        target_under_test = ":custom-crate-name-library",
    )

    default_crate_name_binary_test(
        name = "default_crate_name_binary_test",
        target_under_test = ":default-crate-name-binary",
    )

    custom_crate_name_binary_test(
        name = "custom_crate_name_binary_test",
        target_under_test = ":custom-crate-name-binary",
    )

    default_crate_name_test_test(
        name = "default_crate_name_test_test",
        target_under_test = ":default-crate-name-test",
    )

    custom_crate_name_test_test(
        name = "custom_crate_name_test_test",
        target_under_test = ":custom-crate-name-test",
    )

    invalid_default_crate_name_test(
        name = "invalid_default_crate_name_test",
        target_under_test = ":invalid/default-crate-name",
    )

    invalid_custom_crate_name_test(
        name = "invalid_custom_crate_name_test",
        target_under_test = ":invalid-custom-crate-name",
    )

def crate_name_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """

    _crate_name_test()

    native.test_suite(
        name = name,
        tests = [
            ":default_crate_name_library_test",
            ":custom_crate_name_library_test",
            ":default_crate_name_binary_test",
            ":custom_crate_name_binary_test",
            ":default_crate_name_test_test",
            ":custom_crate_name_test_test",
            ":invalid_default_crate_name_test",
            ":invalid_custom_crate_name_test",
        ],
    )
