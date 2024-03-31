"""Unit tests for repository_utils.bzl."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//rust/platform:triple.bzl", "triple")

# buildifier: disable=bzl-visibility
load(
    "//rust/private:repository_utils.bzl",
    "lookup_tool_sha256",
    "produce_tool_path",
    "produce_tool_suburl",
    "select_rust_version",
)

_PLATFORM_TRIPLE = triple("x86_64-unknown-linux-gnu")

def _produce_tool_suburl_test_impl(ctx):
    env = unittest.begin(ctx)
    asserts.equals(
        env,
        "2020-05-22/rust-std-nightly-x86_64-unknown-linux-gnu",
        produce_tool_suburl(
            iso_date = "2020-05-22",
            tool_name = "rust-std",
            version = "nightly",
            target_triple = _PLATFORM_TRIPLE,
        ),
    )
    asserts.equals(
        env,
        "rust-std-nightly-x86_64-unknown-linux-gnu",
        produce_tool_suburl(
            tool_name = "rust-std",
            version = "nightly",
            target_triple = _PLATFORM_TRIPLE,
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
            target_triple = _PLATFORM_TRIPLE,
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

def _lookup_tool_sha256_test_impl(ctx):
    env = unittest.begin(ctx)

    # Release version included in //rust:known_shas.bzl
    asserts.equals(
        env,
        ("rustc-1.65.0-x86_64-unknown-linux-gnu.tar.xz", "62b89786e195fc5a8a262f83118d6689832b24228c9d303cba8ac14dc1e9adc8"),
        lookup_tool_sha256(
            ctx,
            tool_name = "rustc",
            target_triple = _PLATFORM_TRIPLE,
            version = "1.65.0",
            iso_date = "2022-11-02",
        ),
    )

    # Values in //rust:known_shas.bzl override sha256 arg
    asserts.equals(
        env,
        ("rustc-1.65.0-x86_64-unknown-linux-gnu.tar.xz", "62b89786e195fc5a8a262f83118d6689832b24228c9d303cba8ac14dc1e9adc8"),
        lookup_tool_sha256(
            ctx,
            tool_name = "rustc",
            target_triple = _PLATFORM_TRIPLE,
            version = "1.65.0",
            iso_date = "2022-11-02",
        ),
    )

    # Nightly version included in //rust:known_shas.bzl
    asserts.equals(
        env,
        ("2022-11-02/rust-std-nightly-x86_64-unknown-linux-gnu.tar.xz", "ea01d3cd6c6729cd8ebb55a7702eda2347451e304b58807361e020065a579d96"),
        lookup_tool_sha256(
            ctx,
            tool_name = "rust-std",
            target_triple = _PLATFORM_TRIPLE,
            version = "nightly",
            iso_date = "2022-11-02",
        ),
    )

    # Lookup failure (returns "") for a nightly version not included in //rust:known_shas.bzl
    asserts.equals(
        env,
        ("2022-11-01/rust-std-nightly-x86_64-unknown-linux-gnu.tar.xz", ""),
        lookup_tool_sha256(
            ctx,
            tool_name = "rust-std",
            target_triple = _PLATFORM_TRIPLE,
            version = "nightly",
            iso_date = "2022-11-01",
        ),
    )

    # A nightly version not included in //rust:known_shas.bzl falls back to sha256 arg
    asserts.equals(
        env,
        ("2022-11-01/rust-std-nightly-x86_64-unknown-linux-gnu.tar.xz", ""),
        lookup_tool_sha256(
            ctx,
            tool_name = "rust-std",
            target_triple = _PLATFORM_TRIPLE,
            version = "nightly",
            iso_date = "2022-11-01",
        ),
    )
    return unittest.end(env)

def _select_rust_version_test_impl(ctx):
    env = unittest.begin(ctx)

    # Show stable releases take highest priority
    asserts.equals(
        env,
        "1.66.0",
        select_rust_version(
            versions = [
                "1.66.0",
                "beta/2022-12-15",
                "nightly/2022-12-15",
            ],
        ),
    )

    # Show nightly releases take priority over beta
    asserts.equals(
        env,
        "nightly/2022-12-15",
        select_rust_version(
            versions = [
                "beta/2022-12-15",
                "nightly/2022-12-15",
            ],
        ),
    )

    # Show single versions are safely used.
    for version in ["1.66.0", "beta/2022-12-15", "nightly/2022-12-15"]:
        asserts.equals(
            env,
            version,
            select_rust_version(
                versions = [version],
            ),
        )

    return unittest.end(env)

produce_tool_suburl_test = unittest.make(_produce_tool_suburl_test_impl)
produce_tool_path_test = unittest.make(_produce_tool_path_test_impl)
lookup_tool_sha256_test = unittest.make(_lookup_tool_sha256_test_impl)
select_rust_version_test = unittest.make(_select_rust_version_test_impl)

def repository_utils_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name (str): Name of the macro.
    """
    produce_tool_suburl_test(
        name = "produce_tool_suburl_test",
    )
    produce_tool_path_test(
        name = "produce_tool_path_test",
    )
    lookup_tool_sha256_test(
        name = "lookup_tool_sha256_test",
    )
    select_rust_version_test(
        name = "select_rust_version_test",
    )

    native.test_suite(
        name = name,
        tests = [
            "produce_tool_suburl_test",
            "produce_tool_path_test",
            "lookup_tool_sha256_test",
            "select_rust_version_test",
        ],
    )
