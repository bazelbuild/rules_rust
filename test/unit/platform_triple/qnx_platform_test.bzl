# SPDX-FileCopyrightText: 2026 Contributors to the Eclipse Foundation
# SPDX-License-Identifier: Apache-2.0

"""Tests for QNX platform constraint mappings."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//rust/platform:triple_mappings.bzl", "SUPPORTED_PLATFORM_TRIPLES", "triple_to_constraint_set")

def _qnx_platform_constraints_test_impl(ctx):
    env = unittest.begin(ctx)

    for arch, prefix in [
        ("aarch64", "aarch64-unknown"),
        ("x86_64", "x86_64-pc"),
    ]:
        for abi, version in [
            ("qnx710", "qnx7"),
            ("qnx710_iosock", "qnx7_iosock"),
            ("qnx800", "qnx8"),
        ]:
            target = "{}-nto-{}".format(prefix, abi)
            asserts.true(env, target in SUPPORTED_PLATFORM_TRIPLES, target)
            asserts.equals(
                env,
                [
                    "@platforms//cpu:{}".format(arch),
                    "@platforms//os:qnx",
                    "@rules_rust//rust/platform:{}".format(version),
                ],
                triple_to_constraint_set(target),
                target,
            )

    return unittest.end(env)

qnx_platform_constraints_test = unittest.make(_qnx_platform_constraints_test_impl)

def qnx_platform_test_suite(name, **kwargs):
    """Define the QNX platform mapping test suite.

    Args:
        name: The test suite name.
        **kwargs: Additional test suite attributes.
    """
    qnx_platform_constraints_test(name = "qnx_platform_constraints_test")
    native.test_suite(
        name = name,
        tests = [":qnx_platform_constraints_test"],
        **kwargs
    )
