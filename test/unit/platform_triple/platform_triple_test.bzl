"""Tests for the platform triple constructor"""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//rust/platform:triple.bzl", "triple")
load("//rust/platform:triple_mappings.bzl", "SUPPORTED_PLATFORM_TRIPLES")

def _construct_platform_triple_test_impl(ctx):
    env = unittest.begin(ctx)

    imaginary_triple = triple("arch-vendor-system-abi")

    asserts.equals(
        env,
        "arch",
        imaginary_triple.arch,
    )

    asserts.equals(
        env,
        "vendor",
        imaginary_triple.vendor,
    )

    asserts.equals(
        env,
        "system",
        imaginary_triple.system,
    )

    asserts.equals(
        env,
        "abi",
        imaginary_triple.abi,
    )

    asserts.equals(
        env,
        "arch-vendor-system-abi",
        imaginary_triple.str,
    )

    return unittest.end(env)

def _construct_minimal_platform_triple_test_impl(ctx):
    env = unittest.begin(ctx)

    imaginary_triple = triple("arch-vendor-system")

    asserts.equals(
        env,
        "arch",
        imaginary_triple.arch,
    )

    asserts.equals(
        env,
        "vendor",
        imaginary_triple.vendor,
    )

    asserts.equals(
        env,
        "system",
        imaginary_triple.system,
    )

    asserts.equals(
        env,
        None,
        imaginary_triple.abi,
    )

    asserts.equals(
        env,
        "arch-vendor-system",
        imaginary_triple.str,
    )

    return unittest.end(env)

def _supported_platform_triples_test_impl(ctx):
    env = unittest.begin(ctx)

    for supported_triple in SUPPORTED_PLATFORM_TRIPLES:
        asserts.equals(
            env,
            supported_triple,
            triple(supported_triple).str,
        )

    return unittest.end(env)

construct_platform_triple_test = unittest.make(_construct_platform_triple_test_impl)
construct_minimal_platform_triple_test = unittest.make(_construct_minimal_platform_triple_test_impl)
supported_platform_triples_test = unittest.make(_supported_platform_triples_test_impl)

def platform_triple_test_suite(name):
    construct_platform_triple_test(
        name = "construct_platform_triple_test",
    )
    construct_minimal_platform_triple_test(
        name = "construct_minimal_platform_triple_test",
    )
    supported_platform_triples_test(
        name = "supported_platform_triples_test",
    )

    native.test_suite(
        name = name,
        tests = [
            ":construct_platform_triple_test",
            ":construct_minimal_platform_triple_test",
            ":supported_platform_triples_test",
        ],
    )
