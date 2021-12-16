"""Unittests for rust rules."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//rust:defs.bzl", "rust_test")

def _incompatible_enable_custom_test_launcher_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    executable = tut.files_to_run.executable
    asserts.true(env, executable.basename.endswith(".launcher") or executable.basename.endswith(".launcher.exe"))

    return analysistest.end(env)

def _incompatible_disable_custom_test_launcher_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    executable = tut.files_to_run.executable
    asserts.false(env, executable.basename.endswith(".launcher") or executable.basename.endswith(".launcher.exe"))

    return analysistest.end(env)

incompatible_enable_custom_test_launcher_test = analysistest.make(
    _incompatible_enable_custom_test_launcher_test_impl,
    config_settings = {
        "@//rust/settings:incompatible_disable_custom_test_launcher": False,
    },
)

incompatible_disable_custom_test_launcher_test = analysistest.make(
    _incompatible_disable_custom_test_launcher_test_impl,
    config_settings = {
        "@//rust/settings:incompatible_disable_custom_test_launcher": True,
    },
)

def _disable_custom_test_launcher_test():
    write_file(
        name = "src",
        out = "lib.rs",
        content = [],
    )

    write_file(
        name = "data",
        out = "data.txt",
        content = [],
    )

    rust_test(
        name = "disable_custom_test_launcher_test",
        srcs = [":lib.rs"],
        env = {"CUSTOM_TEST_ENV": "$(execpath :data)"},
        data = [":data"],
    )

    incompatible_enable_custom_test_launcher_test(
        name = "incompatible_enable_custom_test_launcher_test",
        target_under_test = ":disable_custom_test_launcher_test",
    )

    incompatible_disable_custom_test_launcher_test(
        name = "incompatible_disable_custom_test_launcher_test",
        target_under_test = ":disable_custom_test_launcher_test",
    )

def disable_custom_test_launcher_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """
    _disable_custom_test_launcher_test()

    native.test_suite(
        name = name,
        tests = [
            ":incompatible_disable_custom_test_launcher_test",
            ":incompatible_enable_custom_test_launcher_test",
        ],
    )
