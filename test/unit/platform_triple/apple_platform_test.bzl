"""Tests for Apple platform constraint mappings."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//rust/platform:triple_mappings.bzl", "triple_to_constraint_set")

def _apple_platform_constraints_test_impl(ctx):
    env = unittest.begin(ctx)

    aarch64_macabi_constraints = triple_to_constraint_set("aarch64-apple-ios-macabi")
    asserts.equals(
        env,
        [
            "@platforms//cpu:aarch64",
            "@platforms//os:osx",
            "@build_bazel_apple_support//constraints:catalyst",
        ],
        aarch64_macabi_constraints,
        "aarch64-apple-ios-macabi should map to Mac Catalyst constraints",
    )

    x86_64_macabi_constraints = triple_to_constraint_set("x86_64-apple-ios-macabi")
    asserts.equals(
        env,
        [
            "@platforms//cpu:x86_64",
            "@platforms//os:osx",
            "@build_bazel_apple_support//constraints:catalyst",
        ],
        x86_64_macabi_constraints,
        "x86_64-apple-ios-macabi should map to Mac Catalyst constraints",
    )

    x86_64_ios_constraints = triple_to_constraint_set("x86_64-apple-ios")
    asserts.equals(
        env,
        [
            "@platforms//cpu:x86_64",
            "@platforms//os:ios",
            "@build_bazel_apple_support//constraints:simulator",
        ],
        x86_64_ios_constraints,
        "x86_64-apple-ios should remain mapped to iOS simulator constraints",
    )

    return unittest.end(env)

apple_platform_constraints_test = unittest.make(_apple_platform_constraints_test_impl)

def apple_platform_test_suite(name, **kwargs):
    """Define a test suite for Apple platform constraint mappings.

    Args:
        name (str): The name of the test suite.
        **kwargs (dict): Additional keyword arguments for the test_suite.
    """
    apple_platform_constraints_test(
        name = "apple_platform_constraints_test",
    )

    native.test_suite(
        name = name,
        tests = [
            ":apple_platform_constraints_test",
        ],
        **kwargs
    )
