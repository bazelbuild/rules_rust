"""Tests for WASI platform constraint mappings"""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//rust/platform:triple_mappings.bzl", "triple_to_constraint_set")

def _qnx_version_constraints_test_impl(ctx):
    env = unittest.begin(ctx)

    # Test aarch64 QNX7 constraints
    qnx_version_constraints = triple_to_constraint_set("aarch64-unknown-nto-qnx710")
    asserts.equals(
        env,
        [
            "@platforms//cpu:aarch64",
            "@platforms//os:qnx",
            "@rules_rust//rust/platform:qnx7",
        ],
        qnx_version_constraints,
        "aarch64-unknown-nto-qnx710 doesn't map to the appropriate constraints",
    )

    # Test aarch64 QNX7 with iopkt constraints
    qnx_version_constraints = triple_to_constraint_set("aarch64-unknown-nto-qnx710_iosock")
    asserts.equals(
        env,
        [
            "@platforms//cpu:aarch64",
            "@platforms//os:qnx",
            "@rules_rust//rust/platform:qnx7_iosock",
        ],
        qnx_version_constraints,
        "aarch64-unknown-nto-qnx710_iosock doesn't map to the appropriate constraints",
    )

    # Test aarch64 QNX8 constraints
    qnx_version_constraints = triple_to_constraint_set("aarch64-unknown-nto-qnx800")
    asserts.equals(
        env,
        [
            "@platforms//cpu:aarch64",
            "@platforms//os:qnx",
            "@rules_rust//rust/platform:qnx8",
        ],
        qnx_version_constraints,
        "aarch64-unknown-nto-qnx800 doesn't map to the appropriate constraints",
    )

    # Test x86_64 QNX7 constraints
    qnx_version_constraints = triple_to_constraint_set("x86_64-pc-nto-qnx710")
    asserts.equals(
        env,
        [
            "@platforms//cpu:x86_64",
            "@platforms//os:qnx",
            "@rules_rust//rust/platform:qnx7",
        ],
        qnx_version_constraints,
        "x86_64-pc-nto-qnx710 doesn't map to the appropriate constraints",
    )

    # Test x86_64 QNX7 with iosock constraints
    qnx_version_constraints = triple_to_constraint_set("x86_64-pc-nto-qnx710_iosock")
    asserts.equals(
        env,
        [
            "@platforms//cpu:x86_64",
            "@platforms//os:qnx",
            "@rules_rust//rust/platform:qnx7_iosock",
        ],
        qnx_version_constraints,
        "x86_64-pc-nto-qnx710_iosock doesn't map to the appropriate constraints",
    )

    # Test x86_64 QNX8 constraints
    qnx_version_constraints = triple_to_constraint_set("x86_64-pc-nto-qnx800")
    asserts.equals(
        env,
        [
            "@platforms//cpu:x86_64",
            "@platforms//os:qnx",
            "@rules_rust//rust/platform:qnx8",
        ],
        qnx_version_constraints,
        "x86_64-pc-nto-qnx800 doesn't map to the appropriate constraints",
    )

    return unittest.end(env)

_qnx_version_constraints_test = unittest.make(_qnx_version_constraints_test_impl)

def qnx_version_constraints_test(name, **kwargs):
    """Define a test suite for the QNX version to constraints mappings

    Args:
        name (str): The name of the test suite.
        **kwargs (dict): Additional keyword arguments for the test_suite.
    """
    _qnx_version_constraints_test(
        name = "qnx_version_constraints_test",
    )

    native.test_suite(
        name = name,
        tests = [
            ":qnx_version_constraints_test",
        ],
        **kwargs
    )
