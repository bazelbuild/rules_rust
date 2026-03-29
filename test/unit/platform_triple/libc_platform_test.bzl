"""Tests for Linux libc (glibc vs musl) platform constraint mappings."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load(
    "//rust/platform:triple_mappings.bzl",
    "GLIBC_CONSTRAINT",
    "MUSL_CONSTRAINT",
    "triple_to_constraint_set",
)

def _musl_platform_constraints_test_impl(ctx):
    env = unittest.begin(ctx)

    for triple, cpu in [
        ("aarch64-unknown-linux-musl", "aarch64"),
        ("x86_64-unknown-linux-musl", "x86_64"),
        ("arm-unknown-linux-musleabi", "arm"),
        ("armv7-unknown-linux-musleabihf", "armv7"),
        ("i686-unknown-linux-musl", "x86_32"),
        ("powerpc64le-unknown-linux-musl", "ppc64le"),
        ("riscv64gc-unknown-linux-musl", "riscv64"),
        ("s390x-unknown-linux-musl", "s390x"),
    ]:
        asserts.equals(
            env,
            [
                "@platforms//cpu:{}".format(cpu),
                "@platforms//os:linux",
                "@platforms_contrib//os/linux/libc/musl:available",
            ],
            triple_to_constraint_set(triple),
            "{} should require musl to be available on the platform".format(triple),
        )

    return unittest.end(env)

def _glibc_platform_constraints_test_impl(ctx):
    env = unittest.begin(ctx)

    # `gnu` triples must keep matching platforms which do not declare any libc,
    # most importantly Bazel's default host platform `@platforms//host`.
    for triple, cpu, os in [
        ("aarch64-unknown-linux-gnu", "aarch64", "linux"),
        ("x86_64-unknown-linux-gnu", "x86_64", "linux"),
        ("arm-unknown-linux-gnueabi", "arm", "linux"),
        ("x86_64-unknown-nixos-gnu", "x86_64", "nixos"),
    ]:
        asserts.equals(
            env,
            [
                "@platforms//cpu:{}".format(cpu),
                "@platforms//os:{}".format(os),
            ],
            triple_to_constraint_set(triple),
            "{} should not require a specific libc on the platform".format(triple),
        )

    # The musl constraint set must be a strict superset of the glibc one so that
    # `select()` resolves both `config_setting`s matching a musl platform in favor
    # of the musl one.
    gnu_constraints = triple_to_constraint_set("x86_64-unknown-linux-gnu")
    musl_constraints = triple_to_constraint_set("x86_64-unknown-linux-musl")
    for constraint in gnu_constraints:
        asserts.true(env, constraint in musl_constraints)
    asserts.equals(env, len(gnu_constraints) + 1, len(musl_constraints))

    return unittest.end(env)

def _libc_constraint_labels_test_impl(ctx):
    env = unittest.begin(ctx)

    asserts.equals(env, "@platforms_contrib//os/linux/libc/musl:available", MUSL_CONSTRAINT)
    asserts.equals(env, "@platforms_contrib//os/linux/libc/glibc:available", GLIBC_CONSTRAINT)

    # Musl is only distinguished on Linux. `none` targets and friends are unaffected.
    for triple in [
        "thumbv7em-none-eabihf",
        "wasm32-unknown-unknown",
        "x86_64-pc-windows-msvc",
        "aarch64-apple-darwin",
    ]:
        constraints = triple_to_constraint_set(triple)
        asserts.false(env, MUSL_CONSTRAINT in constraints, "{} should not require musl".format(triple))
        asserts.false(env, GLIBC_CONSTRAINT in constraints, "{} should not require glibc".format(triple))

    return unittest.end(env)

musl_platform_constraints_test = unittest.make(_musl_platform_constraints_test_impl)
glibc_platform_constraints_test = unittest.make(_glibc_platform_constraints_test_impl)
libc_constraint_labels_test = unittest.make(_libc_constraint_labels_test_impl)

def libc_platform_test_suite(name, **kwargs):
    """Define a test suite for Linux libc platform constraint mappings.

    Args:
        name (str): The name of the test suite.
        **kwargs (dict): Additional keyword arguments for the test_suite.
    """
    musl_platform_constraints_test(
        name = "musl_platform_constraints_test",
    )
    glibc_platform_constraints_test(
        name = "glibc_platform_constraints_test",
    )
    libc_constraint_labels_test(
        name = "libc_constraint_labels_test",
    )

    native.test_suite(
        name = name,
        tests = [
            ":musl_platform_constraints_test",
            ":glibc_platform_constraints_test",
            ":libc_constraint_labels_test",
        ],
        **kwargs
    )
