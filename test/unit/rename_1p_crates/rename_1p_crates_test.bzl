"""Unit tests for renaming 1P crates."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//rust:defs.bzl", "rust_binary", "rust_library", "rust_test")
load("//test/unit:common.bzl", "assert_argv_contains")

def _default_crate_name_library_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    # Note: crate name encodes entire label.
    assert_argv_contains(env, tut.actions[0], "--crate-name=test_slash_unit_slash_rename_1p_crates_colon_default_dash_crate_dash_name_dash_library")
    return analysistest.end(env)

def _custom_crate_name_library_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    assert_argv_contains(env, tut.actions[0], "--crate-name=custom_name")
    return analysistest.end(env)

def _default_crate_name_binary_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    # Note: crate name encodes entire label.
    assert_argv_contains(env, tut.actions[0], "--crate-name=test_slash_unit_slash_rename_1p_crates_colon_default_dash_crate_dash_name_dash_binary")
    return analysistest.end(env)

def _custom_crate_name_binary_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    assert_argv_contains(env, tut.actions[0], "--crate-name=custom_name")
    return analysistest.end(env)

def _default_crate_name_test_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    # Note: crate name encodes entire label.
    assert_argv_contains(env, tut.actions[0], "--crate-name=test_slash_unit_slash_rename_1p_crates_colon_default_dash_crate_dash_name_dash_test")
    return analysistest.end(env)

def _custom_crate_name_test_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    assert_argv_contains(env, tut.actions[0], "--crate-name=custom_name")
    return analysistest.end(env)

def _must_mangle_default_crate_name_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    # Note: crate name encodes entire label.
    assert_argv_contains(env, tut.actions[0], "--crate-name=test_slash_unit_slash_rename_1p_crates_colon_must_dash_mangle_slash_default_dash_crate_dash_name")
    return analysistest.end(env)

def _invalid_custom_crate_name_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, "contains invalid character(s): -")
    return analysistest.end(env)

config_settings = {
    "//rust/settings:rename_1p_crates": True,
}

default_crate_name_library_test = analysistest.make(
    _default_crate_name_library_test_impl,
    config_settings = config_settings,
)
custom_crate_name_library_test = analysistest.make(
    _custom_crate_name_library_test_impl,
    config_settings = config_settings,
)
default_crate_name_binary_test = analysistest.make(
    _default_crate_name_binary_test_impl,
    config_settings = config_settings,
)
custom_crate_name_binary_test = analysistest.make(
    _custom_crate_name_binary_test_impl,
    config_settings = config_settings,
)
default_crate_name_test_test = analysistest.make(
    _default_crate_name_test_test_impl,
    config_settings = config_settings,
)
custom_crate_name_test_test = analysistest.make(
    _custom_crate_name_test_test_impl,
    config_settings = config_settings,
)
must_mangle_default_crate_name_test = analysistest.make(
    _must_mangle_default_crate_name_test_impl,
    config_settings = config_settings,
)
invalid_custom_crate_name_test = analysistest.make(
    _invalid_custom_crate_name_test_impl,
    config_settings = config_settings,
    expect_failure = True,
)

def _rename_1p_crates_test():
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

    # FIXME: this seems to create this target twice: once with the overridden
    # values in config_settings, and once with the stock values. Since the stock
    # values (i.e. not mangling crate names) disallow '/' characters in target
    # names, this causes an error, which prevents the overridden version of this
    # target from being created and tested.
    # rust_library(
    #     name = "must-mangle/default-crate-name",
    #     srcs = ["lib.rs"],
    # )

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

    # must_mangle_default_crate_name_test(
    #     name = "must_mangle_default_crate_name_test",
    #     target_under_test = ":must-mangle/default-crate-name",
    # )

    invalid_custom_crate_name_test(
        name = "invalid_custom_crate_name_test",
        target_under_test = ":invalid-custom-crate-name",
    )

def rename_1p_crates_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """

    _rename_1p_crates_test()

    native.test_suite(
        name = name,
        tests = [
            ":default_crate_name_library_test",
            ":custom_crate_name_library_test",
            ":default_crate_name_binary_test",
            ":custom_crate_name_binary_test",
            ":default_crate_name_test_test",
            ":custom_crate_name_test_test",
            # ":must_mangle_default_crate_name_test",
            ":invalid_custom_crate_name_test",
        ],
    )
