"""Tests for rust_test sharding support."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_shell//shell:sh_test.bzl", "sh_test")
load("//rust:defs.bzl", "rust_test")

def _sharding_enabled_test(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    executable = tut[DefaultInfo].files_to_run.executable

    asserts.true(
        env,
        executable.basename.endswith("_sharding_wrapper.sh") or
        executable.basename.endswith("_sharding_wrapper.bat"),
        "Expected sharding wrapper script, got: " + executable.basename,
    )

    return analysistest.end(env)

sharding_enabled_test = analysistest.make(_sharding_enabled_test)

def _sharding_disabled_test(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    executable = tut[DefaultInfo].files_to_run.executable

    asserts.false(
        env,
        executable.basename.endswith("_sharding_wrapper.sh") or
        executable.basename.endswith("_sharding_wrapper.bat"),
        "Expected test binary, not wrapper script: " + executable.basename,
    )

    return analysistest.end(env)

sharding_disabled_test = analysistest.make(_sharding_disabled_test)

def _test_sharding_targets():
    rust_test(
        name = "sharded_test_enabled",
        srcs = ["sharded_test.rs"],
        edition = "2021",
        experimental_enable_sharding = True,
    )

    sharding_enabled_test(
        name = "sharding_enabled_test",
        target_under_test = ":sharded_test_enabled",
    )

    rust_test(
        name = "sharded_test_disabled",
        srcs = ["sharded_test.rs"],
        edition = "2021",
        experimental_enable_sharding = False,
    )

    sharding_disabled_test(
        name = "sharding_disabled_test",
        target_under_test = ":sharded_test_disabled",
    )

    rust_test(
        name = "sharded_integration_test",
        srcs = ["sharded_test.rs"],
        edition = "2021",
        experimental_enable_sharding = True,
        shard_count = 3,
    )

    sh_test(
        name = "test_sharding_wrapper_hashes_sorted_names",
        srcs = ["test_sharding_wrapper_hashes_sorted_names.sh"],
        args = [
            "$(location //rust/private:test_sharding_wrapper.sh)",
            "$(location :fake_libtest_binary.sh)",
        ],
        data = [
            ":fake_libtest_binary.sh",
            "//rust/private:test_sharding_wrapper.sh",
        ],
        target_compatible_with = select({
            "@platforms//os:windows": ["@platforms//:incompatible"],
            "//conditions:default": [],
        }),
    )

def test_sharding_test_suite(name):
    _test_sharding_targets()

    native.test_suite(
        name = name,
        tests = [
            ":sharding_enabled_test",
            ":sharding_disabled_test",
            ":test_sharding_wrapper_hashes_sorted_names",
            ":sharded_integration_test",
        ],
    )
