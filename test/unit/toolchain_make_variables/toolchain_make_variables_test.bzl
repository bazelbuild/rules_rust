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

def _rust_toolchain_make_variable_expansion_test_common_impl(ctx, mnemonic):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    action = target.actions[0]

    assert_action_mnemonic(
        env = env,
        action = action,
        mnemonic = mnemonic,
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

def make_toolchain_make_variable_test(impl):
    return analysistest.make(
        impl = impl,
        attrs = {
            "_current_rust_toolchain": attr.label(
                doc = "The currently registered rust toolchain",
                default = Label("//rust/toolchain:current_rust_toolchain"),
            ),
        },
    )

def _rustc_env_variable_expansion_test_impl(ctx):
    return _rust_toolchain_make_variable_expansion_test_common_impl(ctx, "Rustc")

rustc_env_variable_expansion_test = make_toolchain_make_variable_test(
    impl = _rustc_env_variable_expansion_test_impl,
)

def _rust_toolchain_make_variable_expansion_test(ctx):
    return _rust_toolchain_make_variable_expansion_test_common_impl(ctx, "RustToolchainConsumer")

rust_toolchain_make_variable_expansion_test = make_toolchain_make_variable_test(
    impl = _rust_toolchain_make_variable_expansion_test,
)

def _current_rust_toolchain_make_variable_expansion_test_impl(ctx):
    return _rust_toolchain_make_variable_expansion_test_common_impl(ctx, "CurrentRustToolchainConsumer")

current_rust_toolchain_make_variable_expansion_test = make_toolchain_make_variable_test(
    impl = _current_rust_toolchain_make_variable_expansion_test_impl,
)

def _rust_toolchain_consumer_common_impl(ctx, mnemonic):
    output = ctx.actions.declare_file(ctx.label.name)

    args = ctx.actions.args()
    args.add(output)

    # Expand make variables
    env = {
        key: ctx.expand_make_variables(
            key,
            val,
            {},
        )
        for key, val in ctx.attr.env.items()
    }

    ctx.actions.run(
        outputs = [output],
        executable = ctx.executable.writer,
        mnemonic = mnemonic,
        env = env,
        arguments = [args],
    )

    return DefaultInfo(
        files = depset([output]),
    )

def _rust_toolchain_consumer_impl(ctx):
    return _rust_toolchain_consumer_common_impl(ctx, "RustToolchainConsumer")

rust_toolchain_consumer = rule(
    implementation = _rust_toolchain_consumer_impl,
    doc = "A helper rule to test make variable expansion of rules that depend on `rust_toolchain`.",
    attrs = {
        "env": attr.string_dict(
            doc = "Environment variables used for expansion",
            mandatory = True,
        ),
        "writer": attr.label(
            doc = "An executable for creating an action output",
            cfg = "exec",
            executable = True,
            mandatory = True,
        ),
    },
    toolchains = [
        "@rules_rust//rust:toolchain",
    ],
)

def _current_rust_toolchain_consumer_impl(ctx):
    return _rust_toolchain_consumer_common_impl(ctx, "CurrentRustToolchainConsumer")

current_rust_toolchain_consumer = rule(
    implementation = _current_rust_toolchain_consumer_impl,
    doc = "A helper rule to test make variable expansion of `current_rust_toolchain`.",
    attrs = {
        "env": attr.string_dict(
            doc = "Environment variables used for expansion",
            mandatory = True,
        ),
        "writer": attr.label(
            doc = "An executable for creating an action output",
            cfg = "exec",
            executable = True,
            mandatory = True,
        ),
    },
)

def _define_targets():
    rust_library(
        name = "library",
        srcs = ["main.rs"],
        rustc_env = _ENV,
        edition = "2018",
    )

    rust_binary(
        name = "binary",
        srcs = ["main.rs"],
        rustc_env = _ENV,
        edition = "2018",
    )

    rust_test(
        name = "integration_test",
        srcs = ["test.rs"],
        rustc_env = _ENV,
        edition = "2018",
    )

    rust_test(
        name = "unit_test",
        crate = "library",
        rustc_env = _ENV,
    )

    rust_toolchain_consumer(
        name = "rust_toolchain_consumer",
        env = _ENV,
        writer = ":binary",
    )

    current_rust_toolchain_consumer(
        name = "current_rust_toolchain_consumer",
        env = _ENV,
        toolchains = ["//rust/toolchain:current_rust_toolchain"],
        writer = ":binary",
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

    rust_toolchain_make_variable_expansion_test(
        name = "rust_toolchain_make_variable_expansion_test",
        target_under_test = ":rust_toolchain_consumer",
    )

    current_rust_toolchain_make_variable_expansion_test(
        name = "current_rust_toolchain_make_variable_expansion_test",
        target_under_test = ":current_rust_toolchain_consumer",
    )

    native.test_suite(
        name = name,
        tests = [
            ":rustc_env_variable_expansion_library_test",
            ":rustc_env_variable_expansion_binary_test",
            ":rustc_env_variable_expansion_integration_test_test",
            ":rustc_env_variable_expansion_unit_test_test",
            ":rust_toolchain_make_variable_expansion_test",
            ":current_rust_toolchain_make_variable_expansion_test",
        ],
    )
