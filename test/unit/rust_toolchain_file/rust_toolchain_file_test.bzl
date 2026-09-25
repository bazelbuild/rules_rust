"""Unit tests for rust_toolchain_file.bzl."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")

# buildifier: disable=bzl-visibility
load("//rust/private:rust_toolchain_file.bzl", "parse_rust_toolchain_file")

def _stable_release_test_impl(ctx):
    env = unittest.begin(ctx)
    parsed = parse_rust_toolchain_file("""\
# What cargo and rustup read.
[toolchain]
channel = "1.85.0"
components = ["rustfmt", "clippy"]
""")
    asserts.equals(env, ["1.85.0"], parsed.versions)
    asserts.equals(env, [], parsed.extra_target_triples)
    asserts.false(env, parsed.dev_components)
    return unittest.end(env)

def _dated_nightly_test_impl(ctx):
    env = unittest.begin(ctx)
    parsed = parse_rust_toolchain_file("""\
[toolchain]
channel = "nightly-2025-01-01"
components = [
    "rustc-dev",
    "rustfmt",
]
targets = ["wasm32-unknown-unknown", "aarch64-unknown-linux-gnu"]
""")
    asserts.equals(env, ["nightly/2025-01-01"], parsed.versions)
    asserts.equals(env, ["wasm32-unknown-unknown", "aarch64-unknown-linux-gnu"], parsed.extra_target_triples)
    asserts.true(env, parsed.dev_components)
    return unittest.end(env)

def _dated_beta_test_impl(ctx):
    env = unittest.begin(ctx)
    parsed = parse_rust_toolchain_file("""\
[toolchain]
channel = "beta-2025-01-01"
""")
    asserts.equals(env, ["beta/2025-01-01"], parsed.versions)
    return unittest.end(env)

stable_release_test = unittest.make(_stable_release_test_impl)
dated_nightly_test = unittest.make(_dated_nightly_test_impl)
dated_beta_test = unittest.make(_dated_beta_test_impl)

def rust_toolchain_file_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name (str): Name of the macro.
    """
    unittest.suite(
        name,
        stable_release_test,
        dated_nightly_test,
        dated_beta_test,
    )
