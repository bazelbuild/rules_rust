"""Unit tests for semver.bzl."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")

# buildifier: disable=bzl-visibility
load("//rust/private:semver.bzl", "semver")

def _semver_basic_test_impl(ctx):
    env = unittest.begin(ctx)

    # Test basic semver parsing
    result = semver("1.2.3")
    asserts.equals(env, 1, result.major)
    asserts.equals(env, 2, result.minor)
    asserts.equals(env, 3, result.patch)
    asserts.equals(env, None, result.pre)
    asserts.equals(env, None, result.build)
    asserts.equals(env, "1.2.3", result.str)

    # Test with zeros
    result = semver("0.0.0")
    asserts.equals(env, 0, result.major)
    asserts.equals(env, 0, result.minor)
    asserts.equals(env, 0, result.patch)
    asserts.equals(env, None, result.pre)
    asserts.equals(env, None, result.build)
    asserts.equals(env, "0.0.0", result.str)

    # Test larger version numbers
    result = semver("10.20.30")
    asserts.equals(env, 10, result.major)
    asserts.equals(env, 20, result.minor)
    asserts.equals(env, 30, result.patch)
    asserts.equals(env, None, result.pre)
    asserts.equals(env, None, result.build)
    asserts.equals(env, "10.20.30", result.str)

    return unittest.end(env)

def _semver_with_pre_test_impl(ctx):
    env = unittest.begin(ctx)

    # Test semver with pre-release
    result = semver("1.2.3-rc4")
    asserts.equals(env, 1, result.major)
    asserts.equals(env, 2, result.minor)
    asserts.equals(env, 3, result.patch)
    asserts.equals(env, "rc4", result.pre)
    asserts.equals(env, None, result.build)
    asserts.equals(env, "1.2.3-rc4", result.str)

    # Test semver with alpha pre-release
    result = semver("2.0.0-alpha")
    asserts.equals(env, 2, result.major)
    asserts.equals(env, 0, result.minor)
    asserts.equals(env, 0, result.patch)
    asserts.equals(env, "alpha", result.pre)
    asserts.equals(env, None, result.build)
    asserts.equals(env, "2.0.0-alpha", result.str)

    # Test semver with beta pre-release with dot-separated identifier
    result = semver("1.5.0-beta.1")
    asserts.equals(env, 1, result.major)
    asserts.equals(env, 5, result.minor)
    asserts.equals(env, 0, result.patch)
    asserts.equals(env, "beta.1", result.pre)
    asserts.equals(env, None, result.build)
    asserts.equals(env, "1.5.0-beta.1", result.str)

    # Test semver with nightly pre-release
    result = semver("1.70.0-nightly")
    asserts.equals(env, 1, result.major)
    asserts.equals(env, 70, result.minor)
    asserts.equals(env, 0, result.patch)
    asserts.equals(env, "nightly", result.pre)
    asserts.equals(env, None, result.build)
    asserts.equals(env, "1.70.0-nightly", result.str)

    return unittest.end(env)

def _semver_with_build_test_impl(ctx):
    env = unittest.begin(ctx)

    # Plain build metadata, no pre-release.
    result = semver("1.0.0+20130313144700")
    asserts.equals(env, 1, result.major)
    asserts.equals(env, 0, result.minor)
    asserts.equals(env, 0, result.patch)
    asserts.equals(env, None, result.pre)
    asserts.equals(env, "20130313144700", result.build)
    asserts.equals(env, "1.0.0+20130313144700", result.str)

    # Build metadata with dot-separated identifiers (a real semver 2.0 example).
    result = semver("1.0.0+exp.sha.5114f85")
    asserts.equals(env, 1, result.major)
    asserts.equals(env, 0, result.minor)
    asserts.equals(env, 0, result.patch)
    asserts.equals(env, None, result.pre)
    asserts.equals(env, "exp.sha.5114f85", result.build)

    # Pre-release AND build metadata.
    result = semver("1.0.0-beta+exp.sha.5114f85")
    asserts.equals(env, 1, result.major)
    asserts.equals(env, 0, result.minor)
    asserts.equals(env, 0, result.patch)
    asserts.equals(env, "beta", result.pre)
    asserts.equals(env, "exp.sha.5114f85", result.build)
    asserts.equals(env, "1.0.0-beta+exp.sha.5114f85", result.str)

    # Dotted pre-release AND build metadata.
    result = semver("1.2.3-rc.4+build.42")
    asserts.equals(env, 1, result.major)
    asserts.equals(env, 2, result.minor)
    asserts.equals(env, 3, result.patch)
    asserts.equals(env, "rc.4", result.pre)
    asserts.equals(env, "build.42", result.build)

    # Build metadata may itself contain `-` — only the first `+` is the
    # separator; once we're in build metadata, `-` is just a content char.
    result = semver("1.0.0+sha-abcdef")
    asserts.equals(env, None, result.pre)
    asserts.equals(env, "sha-abcdef", result.build)

    return unittest.end(env)

def _semver_edge_cases_test_impl(ctx):
    env = unittest.begin(ctx)

    # Trailing dash: partition keeps an empty pre-release rather than None,
    # since the `-` separator was present.
    result = semver("1.2.3-")
    asserts.equals(env, 1, result.major)
    asserts.equals(env, 2, result.minor)
    asserts.equals(env, 3, result.patch)
    asserts.equals(env, "", result.pre)
    asserts.equals(env, None, result.build)
    asserts.equals(env, "1.2.3-", result.str)

    # Trailing plus: similarly, empty build rather than None.
    result = semver("1.2.3+")
    asserts.equals(env, None, result.pre)
    asserts.equals(env, "", result.build)
    asserts.equals(env, "1.2.3+", result.str)

    # Multiple dashes inside the pre-release: only the first `-` is the
    # separator, so the rest are part of the pre-release identifier.
    result = semver("1.2.3-alpha-test")
    asserts.equals(env, 1, result.major)
    asserts.equals(env, 2, result.minor)
    asserts.equals(env, 3, result.patch)
    asserts.equals(env, "alpha-test", result.pre)
    asserts.equals(env, None, result.build)
    asserts.equals(env, "1.2.3-alpha-test", result.str)

    return unittest.end(env)

def _semver_real_world_examples_test_impl(ctx):
    env = unittest.begin(ctx)

    # A representative sample of versions we ship `rust_toolchain` against.
    for version_str, expected_minor in [
        ("1.54.0", 54),
        ("1.70.0", 70),
        ("1.80.0", 80),
        ("1.87.0", 87),
        ("1.94.1", 94),
    ]:
        result = semver(version_str)
        asserts.equals(env, 1, result.major)
        asserts.equals(env, expected_minor, result.minor)
        asserts.equals(env, None, result.pre)
        asserts.equals(env, None, result.build)
        asserts.equals(env, version_str, result.str)

    # Rust pre-release / nightly shapes that flow through `rust_toolchain`
    # when the version embeds a channel marker rather than a `channel/date`
    # tuple (which is handled separately, before `semver()` is called).
    result = semver("1.87.0-nightly")
    asserts.equals(env, 1, result.major)
    asserts.equals(env, 87, result.minor)
    asserts.equals(env, "nightly", result.pre)

    result = semver("1.87.0-beta.1")
    asserts.equals(env, "beta.1", result.pre)

    return unittest.end(env)

semver_basic_test = unittest.make(_semver_basic_test_impl)
semver_with_pre_test = unittest.make(_semver_with_pre_test_impl)
semver_with_build_test = unittest.make(_semver_with_build_test_impl)
semver_edge_cases_test = unittest.make(_semver_edge_cases_test_impl)
semver_real_world_examples_test = unittest.make(_semver_real_world_examples_test_impl)

def semver_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name (str): Name of the test suite.
    """
    unittest.suite(
        name,
        semver_basic_test,
        semver_with_pre_test,
        semver_with_build_test,
        semver_edge_cases_test,
        semver_real_world_examples_test,
    )
