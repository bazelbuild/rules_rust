"""Unit tests for label injection functions."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")

# buildifier: disable=bzl-visibility
load(
    "//crate_universe/private:common_utils.bzl",
    "sanitize_label_injections",
)

# `sanitize_label_injections` keys at the repo prefix only: keys are the
# canonical repo (e.g. `@@bazel_skylib+`) and values are the apparent repo
# (e.g. `@apparent_repo`). Target portions on either side are dropped on
# ingestion; the Rust pass in `crate_universe/src/config/label_injection.rs`
# performs a substring `replace` of apparent -> canonical over every string in
# an annotation, so any `//pkg:target` the user writes downstream is preserved
# verbatim after the repo prefix is rewritten.

def _sanitize_label_injections_basic_test_impl(ctx):
    """Test sanitize_label_injections with basic inputs."""
    env = unittest.begin(ctx)

    # Empty input maps to empty output.
    asserts.equals(
        env,
        {},
        sanitize_label_injections({}),
    )

    # Apparent label without `//`: value is the bare apparent repo; key has
    # no target appended.
    result = sanitize_label_injections({
        Label("@bazel_skylib//lib:unittest.bzl"): "@apparent_repo",
    })
    asserts.equals(env, 1, len(result))
    canonical_key = result.keys()[0]
    asserts.true(
        env,
        "//" not in canonical_key,
        "Expected canonical key to be a bare repo prefix, got: {}".format(canonical_key),
    )
    asserts.equals(
        env,
        "@apparent_repo",
        result[canonical_key],
    )

    # Apparent label with a full target path: target is stripped from both
    # key (it never had one) and value.
    result = sanitize_label_injections({
        Label("@bazel_skylib//lib:unittest.bzl"): "@apparent_repo//different/path:other",
    })
    asserts.equals(env, 1, len(result))
    canonical_key = result.keys()[0]
    asserts.true(
        env,
        "//" not in canonical_key,
        "Expected canonical key to be a bare repo prefix, got: {}".format(canonical_key),
    )
    asserts.equals(
        env,
        "@apparent_repo",
        result[canonical_key],
    )

    # Apparent label with package path but no explicit target: still
    # collapses to just the repo prefix.
    result = sanitize_label_injections({
        Label("@bazel_skylib//lib:unittest.bzl"): "@apparent_repo//other/path",
    })
    asserts.equals(env, 1, len(result))
    canonical_key = result.keys()[0]
    asserts.true(
        env,
        "//" not in canonical_key,
        "Expected canonical key to be a bare repo prefix, got: {}".format(canonical_key),
    )
    asserts.equals(
        env,
        "@apparent_repo",
        result[canonical_key],
    )

    return unittest.end(env)

def _sanitize_label_injections_multiple_test_impl(ctx):
    """Test sanitize_label_injections with multiple distinct canonical repos."""
    env = unittest.begin(ctx)

    # Three mappings keyed by three distinct canonical repos. Values are
    # the apparent repo prefix; target portions are dropped.
    result = sanitize_label_injections({
        Label("@bazel_skylib//lib:unittest.bzl"): "@my_crates//:tokio",
        Label("@rules_rust//rust:defs.bzl"): "@my_crates//:serde",
        Label("@platforms//os:linux"): "@other_crates//:log",
    })

    asserts.equals(env, 3, len(result))

    values = sorted(result.values())
    asserts.equals(
        env,
        sorted(["@my_crates", "@my_crates", "@other_crates"]),
        values,
    )

    for k in result.keys():
        asserts.true(
            env,
            "//" not in k,
            "Expected canonical key to be a bare repo prefix, got: {}".format(k),
        )

    return unittest.end(env)

def _sanitize_label_injections_same_canonical_repo_test_impl(ctx):
    """Multiple entries mapping the same canonical repo to the same apparent repo dedupe."""
    env = unittest.begin(ctx)

    # Two distinct Label keys that share a canonical repo and point at the
    # same apparent repo collapse to a single entry.
    result = sanitize_label_injections({
        Label("@bazel_skylib//lib:unittest.bzl"): "@my_crates//:tokio",
        Label("@bazel_skylib//lib:dicts.bzl"): "@my_crates//:serde",
    })

    asserts.equals(env, 1, len(result))
    canonical_key = result.keys()[0]
    asserts.true(
        env,
        "//" not in canonical_key,
        "Expected canonical key to be a bare repo prefix, got: {}".format(canonical_key),
    )
    asserts.equals(env, "@my_crates", result[canonical_key])

    return unittest.end(env)

def _sanitize_label_injections_edge_cases_test_impl(ctx):
    """Test sanitize_label_injections edge cases."""
    env = unittest.begin(ctx)

    # Root package label is still resolved to its canonical repo prefix.
    result = sanitize_label_injections({
        Label("//:BUILD.bazel"): "@apparent_repo//:new_target",
    })
    asserts.equals(env, 1, len(result))
    canonical_key = result.keys()[0]
    asserts.true(
        env,
        "//" not in canonical_key,
        "Expected canonical key to be a bare repo prefix, got: {}".format(canonical_key),
    )
    asserts.equals(env, "@apparent_repo", result[canonical_key])

    # Apparent label with dashes / underscores / nested package: value still
    # collapses to the repo prefix.
    result = sanitize_label_injections({
        Label("@bazel_skylib//lib:unittest.bzl"): "@apparent_v2_0//path:target-core",
    })
    asserts.equals(env, 1, len(result))
    canonical_key = result.keys()[0]
    asserts.true(
        env,
        "//" not in canonical_key,
        "Expected canonical key to be a bare repo prefix, got: {}".format(canonical_key),
    )
    asserts.equals(env, "@apparent_v2_0", result[canonical_key])

    # Nested canonical package: only the repo prefix survives in the key.
    result = sanitize_label_injections({
        Label("@bazel_skylib//lib/unittest:unittest.bzl"): "@apparent//shallow:target",
    })
    asserts.equals(env, 1, len(result))
    canonical_key = result.keys()[0]
    asserts.true(
        env,
        "//" not in canonical_key,
        "Expected canonical key to be a bare repo prefix, got: {}".format(canonical_key),
    )
    asserts.equals(env, "@apparent", result[canonical_key])

    return unittest.end(env)

def _sanitize_label_injections_preserves_apparent_test_impl(ctx):
    """Apparent value is always reduced to the repo prefix the user wrote."""
    env = unittest.begin(ctx)

    # Apparent with full target -> value is just the repo prefix.
    result = sanitize_label_injections({
        Label("@bazel_skylib//original/path:original_target"): "@apparent_repo//new/path:new_target",
    })
    asserts.equals(env, 1, len(result))
    canonical_key = result.keys()[0]
    asserts.equals(env, "@apparent_repo", result[canonical_key])

    # Apparent without a target -> value is the repo prefix verbatim.
    result = sanitize_label_injections({
        Label("@bazel_skylib//original/path:original_target"): "@apparent_repo",
    })
    asserts.equals(env, 1, len(result))
    canonical_key = result.keys()[0]
    asserts.equals(env, "@apparent_repo", result[canonical_key])

    return unittest.end(env)

# Create test rules
sanitize_label_injections_basic_test = unittest.make(_sanitize_label_injections_basic_test_impl)
sanitize_label_injections_multiple_test = unittest.make(_sanitize_label_injections_multiple_test_impl)
sanitize_label_injections_same_canonical_repo_test = unittest.make(_sanitize_label_injections_same_canonical_repo_test_impl)
sanitize_label_injections_edge_cases_test = unittest.make(_sanitize_label_injections_edge_cases_test_impl)
sanitize_label_injections_preserves_apparent_test = unittest.make(_sanitize_label_injections_preserves_apparent_test_impl)

def label_injections_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name (str): Name of the test suite.
    """

    sanitize_label_injections_basic_test(
        name = "sanitize_label_injections_basic_test",
    )
    sanitize_label_injections_multiple_test(
        name = "sanitize_label_injections_multiple_test",
    )
    sanitize_label_injections_same_canonical_repo_test(
        name = "sanitize_label_injections_same_canonical_repo_test",
    )
    sanitize_label_injections_edge_cases_test(
        name = "sanitize_label_injections_edge_cases_test",
    )
    sanitize_label_injections_preserves_apparent_test(
        name = "sanitize_label_injections_preserves_apparent_test",
    )

    native.test_suite(
        name = name,
        tests = [
            "sanitize_label_injections_basic_test",
            "sanitize_label_injections_multiple_test",
            "sanitize_label_injections_same_canonical_repo_test",
            "sanitize_label_injections_edge_cases_test",
            "sanitize_label_injections_preserves_apparent_test",
        ],
    )
