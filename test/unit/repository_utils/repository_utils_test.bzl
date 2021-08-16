"""Unit tests for repository_utils.bzl."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")

# buildifier: disable=bzl-visibility
load("//rust/private:repository_utils.bzl", "produce_tool_path", "produce_tool_suburl")

def _produce_tool_suburl_test_impl(ctx):
    env = unittest.begin(ctx)
    asserts.equals(
        env,
        "2020-05-22/rust-std-nightly-x86_64-unknown-linux-gnu",
        produce_tool_suburl(
            iso_date = "2020-05-22",
            tool_name = "rust-std",
            version = "nightly",
            target_triple = "x86_64-unknown-linux-gnu",
        ),
    )
    asserts.equals(
        env,
        "rust-std-nightly-x86_64-unknown-linux-gnu",
        produce_tool_suburl(
            tool_name = "rust-std",
            version = "nightly",
            target_triple = "x86_64-unknown-linux-gnu",
        ),
    )
    asserts.equals(
        env,
        "2020-05-22/rust-src-nightly",
        produce_tool_suburl(
            iso_date = "2020-05-22",
            tool_name = "rust-src",
            version = "nightly",
            target_triple = None,
        ),
    )
    asserts.equals(
        env,
        "rust-src-nightly",
        produce_tool_suburl(
            tool_name = "rust-src",
            version = "nightly",
            target_triple = None,
        ),
    )
    asserts.equals(
        env,
        "rust-src-1.54.0",
        produce_tool_suburl(
            iso_date = "2021-08-15",
            tool_name = "rust-src",
            version = "1.54.0",
            target_triple = None,
        ),
    )
    return unittest.end(env)

def _produce_tool_path_test_impl(ctx):
    env = unittest.begin(ctx)
    asserts.equals(
        env,
        "rust-std-nightly-x86_64-unknown-linux-gnu",
        produce_tool_path(
            tool_name = "rust-std",
            version = "nightly",
            target_triple = "x86_64-unknown-linux-gnu",
        ),
    )
    asserts.equals(
        env,
        "rust-src-nightly",
        produce_tool_path(
            tool_name = "rust-src",
            version = "nightly",
            target_triple = None,
        ),
    )
    return unittest.end(env)

produce_tool_suburl_test = unittest.make(_produce_tool_suburl_test_impl)
produce_tool_path_test = unittest.make(_produce_tool_path_test_impl)

def repository_utils_test_suite(name):
    unittest.suite(
        name,
        produce_tool_suburl_test,
        produce_tool_path_test,
    )
