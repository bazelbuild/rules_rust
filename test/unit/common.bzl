"""Common test helpers for unit tests."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")

def assert_argv_contains_not(env, action, flag):
    asserts.true(
        env,
        flag not in action.argv,
        "Expected {args} to not contain {flag}".format(args = action.argv, flag = flag),
    )

def assert_argv_contains(env, action, flag):
    asserts.true(
        env,
        flag in action.argv,
        "Expected {args} to contain {flag}".format(args = action.argv, flag = flag),
    )

def assert_argv_contains_prefix_suffix(env, action, prefix, suffix):
    for found_flag in action.argv:
        if found_flag.startswith(prefix) and found_flag.endswith(suffix):
            return
    unittest.fail(
        env,
        "Expected an arg with prefix '{prefix}' and suffix '{suffix}' in {args}".format(
            prefix = prefix,
            suffix = suffix,
            args = action.argv,
        ),
    )

