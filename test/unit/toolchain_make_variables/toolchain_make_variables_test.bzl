"""Tests for make variables provided by `rust_toolchain`"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest")
load("//rust:defs.bzl", "rust_binary", "rust_library", "rust_test")
load("//test/unit:common.bzl", "assert_action_mnemonic", "assert_env_value")

_ENV = {
    "ENV_VAR_CARGO": "$(CARGO)",
    "ENV_VAR_RUSTC": "$(RUSTC)",
    "ENV_VAR_RUSTDOC": "$(RUSTDOC)",
    "ENV_VAR_RUSTFMT": "$(RUSTFMT)",
    "ENV_VAR_RUST_DEFAULT_EDITION": "$(RUST_DEFAULT_EDITION)",
    "ENV_VAR_RUST_SYSROOT": "$(RUST_SYSROOT)",
}

def _rustc_env_variable_expansion_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    action = target.actions[0]

    assert_action_mnemonic(
        env = env,
        action = action,
        mnemonic = "Rustc",
    )

    toolchain = ctx.attr._current_rust_toolchain[platform_common.ToolchainInfo]

    expected_values = {
        "ENV_VAR_CARGO": toolchain.cargo.path,
        "ENV_VAR_RUSTC": toolchain.rustc.path,
        "ENV_VAR_RUSTDOC": toolchain.rust_doc.path,
        "ENV_VAR_RUSTFMT": toolchain.rustfmt.path,
        "ENV_VAR_RUST_DEFAULT_EDITION": toolchain.default_edition or "",
        "ENV_VAR_RUST_SYSROOT": toolchain.sysroot,
    }

    for key in _ENV:
        assert_env_value(
            env = env,
            action = action,
            key = key,
            value = expected_values[key],
        )

    return analysistest.end(env)

rustc_env_variable_expansion_test = analysistest.make(
    impl = _rustc_env_variable_expansion_test_impl,
    attrs = {
        "_current_rust_toolchain": attr.label(
            doc = "The currently registered rust toolchain",
            default = Label("//rust/toolchain:current_rust_toolchain"),
        ),
    },
)

def _define_targets():
    rust_library(
        name = "library",
        srcs = ["main.rs"],
        toolchains = ["//rust/toolchain:current_rust_toolchain"],
        rustc_env = _ENV,
        edition = "2018",
    )

    rust_binary(
        name = "binary",
        srcs = ["main.rs"],
        toolchains = ["//rust/toolchain:current_rust_toolchain"],
        rustc_env = _ENV,
        edition = "2018",
    )

    rust_test(
        name = "integration_test",
        srcs = ["main.rs"],
        toolchains = ["//rust/toolchain:current_rust_toolchain"],
        rustc_env = _ENV,
        edition = "2018",
    )

    rust_test(
        name = "unit_test",
        crate = "library",
        toolchains = ["//rust/toolchain:current_rust_toolchain"],
        rustc_env = _ENV,
    )

def toolchain_make_variable_test_suite(name):
    """Defines a test suite

    Args:
        name (str): The name of the test suite
    """
    _define_targets()

    rustc_env_variable_expansion_test(
        name = "rustc_env_variable_expansion_library_test",
        target_under_test = ":library",
    )

    rustc_env_variable_expansion_test(
        name = "rustc_env_variable_expansion_binary_test",
        target_under_test = ":binary",
    )

    rustc_env_variable_expansion_test(
        name = "rustc_env_variable_expansion_integration_test_test",
        target_under_test = ":integration_test",
    )

    rustc_env_variable_expansion_test(
        name = "rustc_env_variable_expansion_unit_test_test",
        target_under_test = ":unit_test",
    )

    native.test_suite(
        name = name,
        tests = [
            ":rustc_env_variable_expansion_library_test",
            ":rustc_env_variable_expansion_binary_test",
            ":rustc_env_variable_expansion_integration_test_test",
            ":rustc_env_variable_expansion_unit_test_test",
        ],
    )
