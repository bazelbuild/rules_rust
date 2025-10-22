"""Tests for BPF platform constraint mappings"""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//rust/platform:triple_mappings.bzl", "triple_to_constraint_set")

def _bpf_platform_constraints_test_impl(ctx):
    env = unittest.begin(ctx)

    bpfeb_constraints = triple_to_constraint_set("bpfeb-unknown-none")
    asserts.equals(
        env,
        [
            "@platforms//os:none",
            "@rules_rust//rust/platform:bpfeb",
        ],
        bpfeb_constraints,
        "bpfeb-unknown-none should map to the BPF big-endian CPU and 'none' OS constraints",
    )

    bpfel_constraints = triple_to_constraint_set("bpfel-unknown-none")
    asserts.equals(
        env,
        [
            "@platforms//os:none",
            "@rules_rust//rust/platform:bpfel",
        ],
        bpfel_constraints,
        "bpfel-unknown-none should map to the BPF little-endian CPU and 'none' OS constraints",
    )

    return unittest.end(env)

bpf_platform_constraints_test = unittest.make(_bpf_platform_constraints_test_impl)

def bpf_platform_test_suite(name, **kwargs):
    """Define a test suite for BPF platform constraint mappings.

    Args:
        name (str): The name of the test suite.
        **kwargs (dict): Additional keyword arguments for the test_suite.
    """
    bpf_platform_constraints_test(
        name = "bpf_platform_constraints_test",
    )

    native.test_suite(
        name = name,
        tests = [
            ":bpf_platform_constraints_test",
        ],
        **kwargs
    )
