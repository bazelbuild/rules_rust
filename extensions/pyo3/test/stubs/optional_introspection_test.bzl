"""Regression tests for toolchains that omit the optional stub dependency."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//:defs.bzl", "pyo3_extension", "rust_pyo3_toolchain")

def _stubs_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)
    stub_actions = [action for action in actions if action.mnemonic == "PyO3StubGen"]
    asserts.equals(env, int(ctx.attr.expect_stubs), len(stub_actions))
    return analysistest.end(env)

def _missing_introspection_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, "PyO3 stub generation requires pyo3_introspection")
    return analysistest.end(env)

def _stub_test(global_stubs, introspection, expect_failure = False):
    return analysistest.make(
        _missing_introspection_test_impl if expect_failure else _stubs_test_impl,
        expect_failure = expect_failure,
        attrs = {"expect_stubs": attr.bool()},
        config_settings = {
            str(Label("//settings:experimental_stubgen")): global_stubs,
            "//command_line_option:extra_toolchains": [str(Label(
                "//toolchains:rust_toolchain" if introspection else "//test/stubs:without_introspection_toolchain",
            ))],
        },
    )

_enabled_with_introspection_test = _stub_test(True, True)
_disabled_with_introspection_test = _stub_test(False, True)
_enabled_without_introspection_test = _stub_test(True, False)
_disabled_without_introspection_test = _stub_test(False, False)
_enabled_missing_introspection_test = _stub_test(True, False, expect_failure = True)
_disabled_missing_introspection_test = _stub_test(False, False, expect_failure = True)

def optional_introspection_test_suite(name):
    """Tests the explicit/inherited stub settings with both toolchain variants.

    Args:
        name: Name of the test suite.
    """
    rust_pyo3_toolchain(
        name = "without_introspection",
        pyo3 = "@rpyo3c//:pyo3",
        tags = ["manual"],
    )
    native.toolchain(
        name = "without_introspection_toolchain",
        toolchain = ":without_introspection",
        toolchain_type = "//:rust_toolchain_type",
    )

    tests = []
    for setting, stubs in [("enabled", True), ("disabled", False), ("inherited", None)]:
        target = "optional_introspection_" + setting
        pyo3_extension(
            name = target,
            srcs = ["string_sum.rs"],
            edition = "2021",
            stubs = stubs,
            tags = ["manual"],
        )
        for global_stubs in [True, False]:
            enabled = stubs if stubs != None else global_stubs
            for introspection in [True, False]:
                if introspection:
                    test_rule = _enabled_with_introspection_test if global_stubs else _disabled_with_introspection_test
                elif enabled:
                    test_rule = _enabled_missing_introspection_test if global_stubs else _disabled_missing_introspection_test
                else:
                    test_rule = _enabled_without_introspection_test if global_stubs else _disabled_without_introspection_test
                test_name = "{}_global_{}_{}_introspection_test".format(
                    target,
                    "enabled" if global_stubs else "disabled",
                    "with" if introspection else "without",
                )
                test_rule(
                    name = test_name,
                    target_under_test = ":" + target,
                    expect_stubs = enabled,
                )
                tests.append(test_name)

    native.test_suite(name = name, tests = tests)
