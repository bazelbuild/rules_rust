"""Tests for rust_test sharding support."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//rust:defs.bzl", "rust_test")

def _sharding_enabled_test(ctx):
    """Test that sharding wrapper is generated when experimental_enable_sharding is True."""
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    # Get the executable from DefaultInfo
    default_info = tut[DefaultInfo]
    executable = default_info.files_to_run.executable

    # When sharding is enabled, the executable should be a wrapper script
    asserts.true(
        env,
        executable.basename.endswith("_sharding_wrapper.sh") or
        executable.basename.endswith("_sharding_wrapper.bat"),
        "Expected sharding wrapper script, got: " + executable.basename,
    )

    return analysistest.end(env)

sharding_enabled_test = analysistest.make(_sharding_enabled_test)

def _sharding_disabled_test(ctx):
    """Test that no wrapper is generated when experimental_enable_sharding is False."""
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    # Get the executable from DefaultInfo
    default_info = tut[DefaultInfo]
    executable = default_info.files_to_run.executable

    # When sharding is disabled, the executable should be the test binary directly
    asserts.false(
        env,
        executable.basename.endswith("_sharding_wrapper.sh") or
        executable.basename.endswith("_sharding_wrapper.bat"),
        "Expected test binary, not wrapper script: " + executable.basename,
    )

    return analysistest.end(env)

sharding_disabled_test = analysistest.make(_sharding_disabled_test)

def _test_sharding_targets():
    """Create test targets for sharding tests."""

    # Test with sharding enabled
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

    # Test with sharding disabled (default)
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

    # Integration test: actually run a sharded test
    rust_test(
        name = "sharded_integration_test",
        srcs = ["sharded_test.rs"],
        edition = "2021",
        experimental_enable_sharding = True,
        shard_count = 3,
    )

def test_sharding_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """

    _test_sharding_targets()

    native.test_suite(
        name = name,
        tests = [
            ":sharding_enabled_test",
            ":sharding_disabled_test",
            ":sharded_integration_test",
        ],
    )
