"""Tests for make variables provided by `rust_toolchain` and its companion toolchains"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest")
load("//rust:defs.bzl", "rust_binary", "rust_library", "rust_test")
load("//test/unit:common.bzl", "assert_action_mnemonic", "assert_env_value")

_RUST_TOOLCHAIN_ENV = {
    "ENV_VAR_CARGO": "$(CARGO)",
    "ENV_VAR_RUSTC": "$(RUSTC)",
    "ENV_VAR_RUST_DEFAULT_EDITION": "$(RUST_DEFAULT_EDITION)",
    "ENV_VAR_RUST_SYSROOT": "$(RUST_SYSROOT)",
}

_RUSTFMT_TOOLCHAIN_ENV = {
    "ENV_VAR_RUSTFMT": "$(RUSTFMT)",
}

_RUSTDOC_TOOLCHAIN_ENV = {
    "ENV_VAR_RUSTDOC": "$(RUSTDOC)",
}

_CLIPPY_TOOLCHAIN_ENV = {
    "ENV_VAR_CARGO_CLIPPY": "$(CARGO_CLIPPY)",
    "ENV_VAR_CLIPPY_DRIVER": "$(CLIPPY_DRIVER)",
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

    if mnemonic in ["RustFmtToolchainConsumer", "CurrentRustFmtToolchainConsumer"]:
        toolchain = ctx.attr._current_rustfmt_toolchain[platform_common.ToolchainInfo]
        env_vars = _RUSTFMT_TOOLCHAIN_ENV
        expected_values = {
            "ENV_VAR_RUSTFMT": toolchain.rustfmt.path,
        }
    elif mnemonic in ["RustdocToolchainConsumer", "CurrentRustdocToolchainConsumer"]:
        toolchain = ctx.attr._current_rustdoc_toolchain[platform_common.ToolchainInfo]
        env_vars = _RUSTDOC_TOOLCHAIN_ENV
        expected_values = {
            "ENV_VAR_RUSTDOC": toolchain.rustdoc.path,
        }
    elif mnemonic in ["ClippyToolchainConsumer", "CurrentClippyToolchainConsumer"]:
        toolchain = ctx.attr._current_clippy_toolchain[platform_common.ToolchainInfo]
        env_vars = _CLIPPY_TOOLCHAIN_ENV
        expected_values = {
            "ENV_VAR_CARGO_CLIPPY": toolchain.cargo_clippy.path,
            "ENV_VAR_CLIPPY_DRIVER": toolchain.clippy_driver.path,
        }
    else:
        toolchain = ctx.attr._current_rust_toolchain[platform_common.ToolchainInfo]
        env_vars = _RUST_TOOLCHAIN_ENV
        expected_values = {
            "ENV_VAR_CARGO": toolchain.cargo.path,
            "ENV_VAR_RUSTC": toolchain.rustc.path,
            "ENV_VAR_RUST_DEFAULT_EDITION": toolchain.default_edition or "",
            "ENV_VAR_RUST_SYSROOT": toolchain.sysroot,
        }

    for key in env_vars:
        assert_env_value(
            env = env,
            action = action,
            key = key,
            value = expected_values[key],
        )

    return analysistest.end(env)

def rust_toolchain_make_toolchain_make_variable_test(impl):
    return analysistest.make(
        impl = impl,
        attrs = {
            "_current_rust_toolchain": attr.label(
                doc = "The currently registered rust toolchain",
                default = Label("//rust/toolchain:current_rust_toolchain"),
            ),
        },
    )

def rustfmt_toolchain_make_toolchain_make_variable_test(impl):
    return analysistest.make(
        impl = impl,
        attrs = {
            "_current_rustfmt_toolchain": attr.label(
                doc = "The currently registered rustfmt toolchain",
                default = Label("//rust/toolchain:current_rustfmt_toolchain"),
            ),
        },
    )

def rustdoc_toolchain_make_toolchain_make_variable_test(impl):
    return analysistest.make(
        impl = impl,
        attrs = {
            "_current_rustdoc_toolchain": attr.label(
                doc = "The currently registered rustdoc toolchain",
                default = Label("//rust/toolchain:current_rustdoc_toolchain"),
            ),
        },
    )

def clippy_toolchain_make_toolchain_make_variable_test(impl):
    return analysistest.make(
        impl = impl,
        attrs = {
            "_current_clippy_toolchain": attr.label(
                doc = "The currently registered clippy toolchain",
                default = Label("//rust/toolchain:current_clippy_toolchain"),
            ),
        },
    )

def _rustc_env_variable_expansion_test_impl(ctx):
    return _rust_toolchain_make_variable_expansion_test_common_impl(ctx, "Rustc")

rustc_env_variable_expansion_test = rust_toolchain_make_toolchain_make_variable_test(
    impl = _rustc_env_variable_expansion_test_impl,
)

def _rust_toolchain_make_variable_expansion_test(ctx):
    return _rust_toolchain_make_variable_expansion_test_common_impl(ctx, "RustToolchainConsumer")

rust_toolchain_make_variable_expansion_test = rust_toolchain_make_toolchain_make_variable_test(
    impl = _rust_toolchain_make_variable_expansion_test,
)

def _current_rust_toolchain_make_variable_expansion_test_impl(ctx):
    return _rust_toolchain_make_variable_expansion_test_common_impl(ctx, "CurrentRustToolchainConsumer")

current_rust_toolchain_make_variable_expansion_test = rust_toolchain_make_toolchain_make_variable_test(
    impl = _current_rust_toolchain_make_variable_expansion_test_impl,
)

def _rustfmt_env_variable_expansion_test_impl(ctx):
    return _rust_toolchain_make_variable_expansion_test_common_impl(ctx, "RustFmtToolchainConsumer")

rustfmt_env_variable_expansion_test = rustfmt_toolchain_make_toolchain_make_variable_test(
    impl = _rustfmt_env_variable_expansion_test_impl,
)

def _current_rustfmt_toolchain_make_variable_expansion_test_impl(ctx):
    return _rust_toolchain_make_variable_expansion_test_common_impl(ctx, "CurrentRustFmtToolchainConsumer")

current_rustfmt_toolchain_make_variable_expansion_test = rustfmt_toolchain_make_toolchain_make_variable_test(
    impl = _current_rustfmt_toolchain_make_variable_expansion_test_impl,
)

def _rustdoc_env_variable_expansion_test_impl(ctx):
    return _rust_toolchain_make_variable_expansion_test_common_impl(ctx, "RustdocToolchainConsumer")

rustdoc_env_variable_expansion_test = rustdoc_toolchain_make_toolchain_make_variable_test(
    impl = _rustdoc_env_variable_expansion_test_impl,
)

def _current_rustdoc_toolchain_make_variable_expansion_test_impl(ctx):
    return _rust_toolchain_make_variable_expansion_test_common_impl(ctx, "CurrentRustdocToolchainConsumer")

current_rustdoc_toolchain_make_variable_expansion_test = rustdoc_toolchain_make_toolchain_make_variable_test(
    impl = _current_rustdoc_toolchain_make_variable_expansion_test_impl,
)

def _clippy_env_variable_expansion_test_impl(ctx):
    return _rust_toolchain_make_variable_expansion_test_common_impl(ctx, "ClippyToolchainConsumer")

clippy_env_variable_expansion_test = clippy_toolchain_make_toolchain_make_variable_test(
    impl = _clippy_env_variable_expansion_test_impl,
)

def _current_clippy_toolchain_make_variable_expansion_test_impl(ctx):
    return _rust_toolchain_make_variable_expansion_test_common_impl(ctx, "CurrentClippyToolchainConsumer")

current_clippy_toolchain_make_variable_expansion_test = clippy_toolchain_make_toolchain_make_variable_test(
    impl = _current_clippy_toolchain_make_variable_expansion_test_impl,
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
        "@rules_rust//rust:toolchain_type",
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

def _rustfmt_toolchain_consumer_impl(ctx):
    return _rust_toolchain_consumer_common_impl(ctx, "RustFmtToolchainConsumer")

rustfmt_toolchain_consumer = rule(
    implementation = _rustfmt_toolchain_consumer_impl,
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
        "@rules_rust//rust/rustfmt:toolchain_type",
    ],
)

def _current_rustfmt_toolchain_consumer_impl(ctx):
    return _rust_toolchain_consumer_common_impl(ctx, "CurrentRustFmtToolchainConsumer")

current_rustfmt_toolchain_consumer = rule(
    implementation = _current_rustfmt_toolchain_consumer_impl,
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
    toolchains = [
        "@rules_rust//rust/rustfmt:toolchain_type",
    ],
)

_CONSUMER_ATTRS = {
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
}

def _rustdoc_toolchain_consumer_impl(ctx):
    return _rust_toolchain_consumer_common_impl(ctx, "RustdocToolchainConsumer")

rustdoc_toolchain_consumer = rule(
    implementation = _rustdoc_toolchain_consumer_impl,
    doc = "A helper rule to test make variable expansion of rules that depend on `rustdoc_toolchain`.",
    attrs = _CONSUMER_ATTRS,
    toolchains = [
        "@rules_rust//rust/rustdoc:toolchain_type",
    ],
)

def _current_rustdoc_toolchain_consumer_impl(ctx):
    return _rust_toolchain_consumer_common_impl(ctx, "CurrentRustdocToolchainConsumer")

current_rustdoc_toolchain_consumer = rule(
    implementation = _current_rustdoc_toolchain_consumer_impl,
    doc = "A helper rule to test make variable expansion of `current_rustdoc_toolchain`.",
    attrs = _CONSUMER_ATTRS,
)

def _clippy_toolchain_consumer_impl(ctx):
    return _rust_toolchain_consumer_common_impl(ctx, "ClippyToolchainConsumer")

clippy_toolchain_consumer = rule(
    implementation = _clippy_toolchain_consumer_impl,
    doc = "A helper rule to test make variable expansion of rules that depend on `clippy_toolchain`.",
    attrs = _CONSUMER_ATTRS,
    toolchains = [
        "@rules_rust//rust/clippy:toolchain_type",
    ],
)

def _current_clippy_toolchain_consumer_impl(ctx):
    return _rust_toolchain_consumer_common_impl(ctx, "CurrentClippyToolchainConsumer")

current_clippy_toolchain_consumer = rule(
    implementation = _current_clippy_toolchain_consumer_impl,
    doc = "A helper rule to test make variable expansion of `current_clippy_toolchain`.",
    attrs = _CONSUMER_ATTRS,
)

def _define_targets():
    rust_library(
        name = "library",
        srcs = ["main.rs"],
        rustc_env = _RUST_TOOLCHAIN_ENV,
        edition = "2018",
    )

    rust_binary(
        name = "binary",
        srcs = ["main.rs"],
        rustc_env = _RUST_TOOLCHAIN_ENV,
        edition = "2018",
    )

    rust_test(
        name = "integration_test",
        srcs = ["test.rs"],
        rustc_env = _RUST_TOOLCHAIN_ENV,
        edition = "2018",
    )

    rust_test(
        name = "unit_test",
        crate = "library",
        rustc_env = _RUST_TOOLCHAIN_ENV,
    )

    rust_toolchain_consumer(
        name = "rust_toolchain_consumer",
        env = _RUST_TOOLCHAIN_ENV,
        writer = ":binary",
    )

    current_rust_toolchain_consumer(
        name = "current_rust_toolchain_consumer",
        env = _RUST_TOOLCHAIN_ENV,
        toolchains = ["//rust/toolchain:current_rust_toolchain"],
        writer = ":binary",
    )

    rustfmt_toolchain_consumer(
        name = "rustfmt_toolchain_consumer",
        env = _RUSTFMT_TOOLCHAIN_ENV,
        writer = ":binary",
    )

    current_rustfmt_toolchain_consumer(
        name = "current_rustfmt_toolchain_consumer",
        env = _RUSTFMT_TOOLCHAIN_ENV,
        toolchains = ["//rust/toolchain:current_rustfmt_toolchain"],
        writer = ":binary",
    )

    rustdoc_toolchain_consumer(
        name = "rustdoc_toolchain_consumer",
        env = _RUSTDOC_TOOLCHAIN_ENV,
        writer = ":binary",
    )

    current_rustdoc_toolchain_consumer(
        name = "current_rustdoc_toolchain_consumer",
        env = _RUSTDOC_TOOLCHAIN_ENV,
        toolchains = ["//rust/toolchain:current_rustdoc_toolchain"],
        writer = ":binary",
    )

    clippy_toolchain_consumer(
        name = "clippy_toolchain_consumer",
        env = _CLIPPY_TOOLCHAIN_ENV,
        writer = ":binary",
    )

    current_clippy_toolchain_consumer(
        name = "current_clippy_toolchain_consumer",
        env = _CLIPPY_TOOLCHAIN_ENV,
        toolchains = ["//rust/toolchain:current_clippy_toolchain"],
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

    rustfmt_env_variable_expansion_test(
        name = "rustfmt_env_variable_expansion_test",
        target_under_test = ":rustfmt_toolchain_consumer",
    )

    current_rustfmt_toolchain_make_variable_expansion_test(
        name = "current_rustfmt_toolchain_make_variable_expansion_test",
        target_under_test = ":current_rustfmt_toolchain_consumer",
    )

    rustdoc_env_variable_expansion_test(
        name = "rustdoc_env_variable_expansion_test",
        target_under_test = ":rustdoc_toolchain_consumer",
    )

    current_rustdoc_toolchain_make_variable_expansion_test(
        name = "current_rustdoc_toolchain_make_variable_expansion_test",
        target_under_test = ":current_rustdoc_toolchain_consumer",
    )

    clippy_env_variable_expansion_test(
        name = "clippy_env_variable_expansion_test",
        target_under_test = ":clippy_toolchain_consumer",
    )

    current_clippy_toolchain_make_variable_expansion_test(
        name = "current_clippy_toolchain_make_variable_expansion_test",
        target_under_test = ":current_clippy_toolchain_consumer",
    )

    native.test_suite(
        name = name,
        tests = [
            # rust_toolchain tests
            ":rustc_env_variable_expansion_library_test",
            ":rustc_env_variable_expansion_binary_test",
            ":rustc_env_variable_expansion_integration_test_test",
            ":rustc_env_variable_expansion_unit_test_test",
            ":rust_toolchain_make_variable_expansion_test",
            ":current_rust_toolchain_make_variable_expansion_test",
        ] + [
            # rustfmt_toolchain tests
            ":rustfmt_env_variable_expansion_test",
            ":current_rustfmt_toolchain_make_variable_expansion_test",
        ] + [
            # rustdoc_toolchain tests
            ":rustdoc_env_variable_expansion_test",
            ":current_rustdoc_toolchain_make_variable_expansion_test",
        ] + [
            # clippy_toolchain tests
            ":clippy_env_variable_expansion_test",
            ":current_clippy_toolchain_make_variable_expansion_test",
        ],
    )
