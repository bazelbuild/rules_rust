"""Starlark tests for `//rust/settings:experimental_incremental`"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//rust:defs.bzl", "rust_library", "rust_proc_macro")
load(
    "//test/unit:common.bzl",
    "assert_action_mnemonic",
    "assert_argv_contains_prefix",
    "assert_argv_contains_prefix_not",
)

# Checks that -Cincremental flag is present in Rustc action
def _incremental_enabled_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    action = target.actions[0]
    assert_action_mnemonic(env, action, "Rustc")
    assert_argv_contains_prefix(env, action, "-Cincremental=")

    return analysistest.end(env)

_incremental_enabled_test = analysistest.make(
    _incremental_enabled_test_impl,
    config_settings = {
        str(Label("//rust/settings:experimental_incremental")): True,
    },
)

# Checks that -Cincremental flag is absent by default
def _incremental_disabled_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    action = target.actions[0]
    assert_action_mnemonic(env, action, "Rustc")
    assert_argv_contains_prefix_not(env, action, "-Cincremental")

    return analysistest.end(env)

_incremental_disabled_test = analysistest.make(
    _incremental_disabled_test_impl,
    config_settings = {},
)

# Checks that -Cincremental flag is NOT added for proc-macros even when enabled
def _incremental_proc_macro_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    action = target.actions[0]
    assert_action_mnemonic(env, action, "Rustc")
    assert_argv_contains_prefix_not(env, action, "-Cincremental")

    return analysistest.end(env)

_incremental_proc_macro_test = analysistest.make(
    _incremental_proc_macro_test_impl,
    config_settings = {
        str(Label("//rust/settings:experimental_incremental")): True,
    },
)

# Checks the incremental cache path contains the crate name
def _incremental_cache_path_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    action = target.actions[0]
    assert_action_mnemonic(env, action, "Rustc")
    assert_argv_contains_prefix(env, action, "-Cincremental=/tmp/rules_rust_incremental/")

    return analysistest.end(env)

_incremental_cache_path_test = analysistest.make(
    _incremental_cache_path_test_impl,
    config_settings = {
        str(Label("//rust/settings:experimental_incremental")): True,
    },
)

def incremental_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name (str): The name of the test suite.
    """
    write_file(
        name = "crate_lib",
        out = "lib.rs",
        content = [
            "#[allow(dead_code)]",
            "fn add() {}",
            "",
        ],
    )

    rust_library(
        name = "lib",
        srcs = [":lib.rs"],
        edition = "2021",
    )

    rust_proc_macro(
        name = "proc_macro",
        srcs = [":lib.rs"],
        edition = "2021",
    )

    _incremental_enabled_test(
        name = "incremental_enabled_test",
        target_under_test = ":lib",
    )

    _incremental_disabled_test(
        name = "incremental_disabled_test",
        target_under_test = ":lib",
    )

    _incremental_proc_macro_test(
        name = "incremental_proc_macro_test",
        target_under_test = ":proc_macro",
    )

    _incremental_cache_path_test(
        name = "incremental_cache_path_test",
        target_under_test = ":lib",
    )

    native.test_suite(
        name = name,
        tests = [
            ":incremental_enabled_test",
            ":incremental_disabled_test",
            ":incremental_proc_macro_test",
            ":incremental_cache_path_test",
        ],
    )
