"""Tests for the @rules_rust//rust/settings:rust_test_prefix_output_files flag."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//rust:defs.bzl", "rust_test")

def _rust_test_prefix_output_files_transition_impl(_settings, attr):
    return {
        "//rust/settings:rust_test_prefix_output_files": attr.rust_test_prefix_output_files,
    }

_rust_test_prefix_output_files_transition = transition(
    implementation = _rust_test_prefix_output_files_transition_impl,
    inputs = [],
    outputs = ["//rust/settings:rust_test_prefix_output_files"],
)

def _with_rust_test_prefix_output_files_cfg_impl(ctx):
    return [DefaultInfo(files = depset(ctx.files.srcs))]

with_rust_test_prefix_output_files_cfg = rule(
    implementation = _with_rust_test_prefix_output_files_cfg_impl,
    attrs = {
        "rust_test_prefix_output_files": attr.bool(
            mandatory = True,
        ),
        "srcs": attr.label_list(
            allow_files = True,
            cfg = _rust_test_prefix_output_files_transition,
        ),
        "_allowlist_function_transition": attr.label(
            default = Label("//tools/allowlists/function_transition_allowlist"),
        ),
    },
)

def _output_paths_test(ctx):
    env = analysistest.begin(ctx)

    files = ctx.attr.target_under_test.files.to_list()
    asserts.equals(env, 1, len(files))

    test_binary = files[0]
    if ctx.attr.expect_output_hash:
        # The output hash is injected between the rule's directory path and
        # the rust_test binary name.
        asserts.false(env, "test_prefix_setting/test_binary" in test_binary.short_path)
    else:
        # With no output hash, the rust_test binary is placed directly under
        # the rule's directory path.
        asserts.true(env, "test_prefix_setting/test_binary" in test_binary.short_path)

    return analysistest.end(env)

output_paths_test = analysistest.make(
    _output_paths_test,
    attrs = {
        "expect_output_hash": attr.bool(mandatory = True),
    },
)

def prefix_setting_tests(name, **kwargs):
    """Macro for declaring test_prefix_setting test targets.

    Args:
        name (str): The name of the test suite
        **kwargs (dict): Additional keyword arguments for the underlying test_suite.
    """

    rust_test(
        name = "test_binary",
        srcs = ["lib.rs"],
        edition = "2018",
        tags = ["manual"],
    )

    with_rust_test_prefix_output_files_cfg(
        name = "test_binary_with_output_hash",
        testonly = True,
        srcs = [":test_binary"],
        rust_test_prefix_output_files = True,
    )

    with_rust_test_prefix_output_files_cfg(
        name = "test_binary_without_output_hash",
        testonly = True,
        srcs = [":test_binary"],
        rust_test_prefix_output_files = False,
    )

    output_paths_test(
        name = "with_output_hash_test",
        expect_output_hash = True,
        target_under_test = ":test_binary_with_output_hash",
    )

    output_paths_test(
        name = "without_output_hash_test",
        expect_output_hash = False,
        target_under_test = ":test_binary_without_output_hash",
    )

    native.test_suite(
        name = name,
        tests = [
            ":with_output_hash_test",
            ":without_output_hash_test",
        ],
        **kwargs
    )
