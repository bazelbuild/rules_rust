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

def assert_action_mnemonic(env, action, mnemonic):
    if not action.mnemonic == mnemonic:
        unittest.fail(
            env,
            "Expected the action to have the mnemonic '{expected}', but got '{actual}'".format(
                expected = mnemonic,
                actual = action.mnemonic,
            ),
        )

def _startswith(list, prefix):
    if len(list) < len(prefix):
        return False
    for pair in zip(list[:len(prefix) + 1], prefix):
        if pair[0] != pair[1]:
            return False
    return True

def assert_argv_contains_in_order(env, action, flags):
    argv = action.argv
    for idx in range(len(argv)):
        if argv[idx] == flags[0]:
            if _startswith(argv[idx:], flags):
                return

    unittest.fail(
        env,
        "Expected the to find '{expected}' within '{actual}'".format(
            expected = flags,
            actual = argv,
        ),
    )

def assert_argv_contains_in_order_not(env, action, flags):
    argv = action.argv
    for idx in range(len(argv)):
        if argv[idx] == flags[0]:
            if _startswith(argv[idx:], flags):
                unittest.fail(
                    env,
                    "Expected not the to find '{expected}' within '{actual}'".format(
                        expected = flags,
                        actual = argv,
                    ),
                )
