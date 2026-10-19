"""Tests that the Cargo toolchain stays in lockstep with the Rust toolchain."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts", "unittest")
load("//cargo:cargo_toolchain.bzl", "cargo_version_mismatch")
load("//rust:defs.bzl", "rust_common")

_ResolvedVersionsInfo = provider(
    doc = "The release identifiers of the resolved Cargo and Rust toolchains.",
    fields = ["cargo", "rust"],
)

def _identifiers(toolchain):
    return struct(
        version = toolchain.version,
        iso_date = toolchain.iso_date,
        channel = toolchain.channel,
    )

def _resolved_versions_impl(ctx):
    return [_ResolvedVersionsInfo(
        cargo = _identifiers(ctx.toolchains[rust_common.cargo_toolchain_type]),
        rust = _identifiers(ctx.toolchains[rust_common.toolchain_type]),
    )]

resolved_versions = rule(
    implementation = _resolved_versions_impl,
    doc = "Resolves both toolchains for the current platform and reports their release identifiers.",
    toolchains = [
        config_common.toolchain_type(rust_common.cargo_toolchain_type),
        config_common.toolchain_type(rust_common.toolchain_type),
    ],
)

def _registered_toolchains_match_test_impl(ctx):
    env = analysistest.begin(ctx)
    info = analysistest.target_under_test(env)[_ResolvedVersionsInfo]

    asserts.true(env, bool(info.rust.version), "The registered `rust_toolchain` should state a version")
    asserts.true(env, bool(info.cargo.version), "The registered `cargo_toolchain` should state a version")
    for field in ("version", "iso_date", "channel"):
        asserts.equals(
            env,
            getattr(info.rust, field),
            getattr(info.cargo, field),
            "`cargo_toolchain` and `rust_toolchain` should agree on `{}`".format(field),
        )
    asserts.equals(env, None, cargo_version_mismatch(info.cargo, info.rust))

    return analysistest.end(env)

registered_toolchains_match_test = analysistest.make(_registered_toolchains_match_test_impl)

def _cargo_version_mismatch_test_impl(ctx):
    env = unittest.begin(ctx)

    stable = struct(version = "1.98.0", iso_date = "", channel = "stable")
    nightly = struct(version = "1.100.0", iso_date = "2026-08-20", channel = "nightly")
    other_nightly = struct(version = "1.100.0", iso_date = "2026-09-03", channel = "nightly")
    unversioned = struct(version = "", iso_date = "", channel = "")

    asserts.equals(env, None, cargo_version_mismatch(stable, stable))
    asserts.equals(env, None, cargo_version_mismatch(nightly, nightly))

    # Toolchains which do not state identifiers are never rejected.
    asserts.equals(env, None, cargo_version_mismatch(unversioned, stable))
    asserts.equals(env, None, cargo_version_mismatch(stable, unversioned))
    asserts.equals(env, None, cargo_version_mismatch(None, stable))
    asserts.equals(env, None, cargo_version_mismatch(stable, None))

    # Any stated identifier that differs is a mismatch.
    asserts.true(env, "version 1.98.0" in cargo_version_mismatch(stable, nightly))
    asserts.true(env, "iso_date 2026-08-20" in cargo_version_mismatch(nightly, other_nightly))

    return unittest.end(env)

cargo_version_mismatch_test = unittest.make(_cargo_version_mismatch_test_impl)

def cargo_toolchain_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name (str): The name of the test suite.
    """
    resolved_versions(
        name = "resolved_versions",
        tags = ["manual"],
    )

    registered_toolchains_match_test(
        name = "registered_toolchains_match_test",
        target_under_test = ":resolved_versions",
    )

    cargo_version_mismatch_test(
        name = "cargo_version_mismatch_test",
    )

    native.test_suite(
        name = name,
        tests = [
            ":registered_toolchains_match_test",
            ":cargo_version_mismatch_test",
        ],
    )
