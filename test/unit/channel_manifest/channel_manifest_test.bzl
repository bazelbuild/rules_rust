"""Unit tests for channel_manifest.bzl: what a channel manifest looks like and what is read out of it."""

load("@rules_testing//lib:test_suite.bzl", "test_suite")

# buildifier: disable=bzl-visibility
load(
    "//rust/private:channel_manifest.bzl",
    "archive_extension",
    "manifest_urls",
    "parse_manifest",
    "split_version",
)

# An excerpt of `channel-rust-1.99.0.toml`, as published at
# https://static.rust-lang.org/dist/channel-rust-1.99.0.toml. A release's
# manifest lists every package for every target, with the archive of each in
# both formats. Packages the release does not build for a target are listed
# as unavailable, without archives. Target-independent packages such as
# `rust-src` are listed under the target `*`. Some packages are published
# under another name than their manifest key: `clippy-preview` is
# `clippy-<version>-<target>`, which is why the names are taken from `url`.
_STABLE_MANIFEST = """\
manifest-version = "2"
date = "2026-10-23"

[pkg.rust-std]
version = "1.99.0 (abcdef012 2026-10-21)"

[pkg.rust-std.target.x86_64-unknown-linux-gnu]
available = true
url = "https://static.rust-lang.org/dist/2026-10-23/rust-std-1.99.0-x86_64-unknown-linux-gnu.tar.gz"
hash = "1111111111111111111111111111111111111111111111111111111111111111"
xz_url = "https://static.rust-lang.org/dist/2026-10-23/rust-std-1.99.0-x86_64-unknown-linux-gnu.tar.xz"
xz_hash = "2222222222222222222222222222222222222222222222222222222222222222"

[pkg.rust-std.target.aarch64-apple-darwin]
available = true
url = "https://static.rust-lang.org/dist/2026-10-23/rust-std-1.99.0-aarch64-apple-darwin.tar.gz"
hash = "3333333333333333333333333333333333333333333333333333333333333333"
xz_url = "https://static.rust-lang.org/dist/2026-10-23/rust-std-1.99.0-aarch64-apple-darwin.tar.xz"
xz_hash = "4444444444444444444444444444444444444444444444444444444444444444"

[pkg.rustc.target.x86_64-unknown-linux-gnu]
available = true
url = "https://static.rust-lang.org/dist/2026-10-23/rustc-1.99.0-x86_64-unknown-linux-gnu.tar.gz"
hash = "5555555555555555555555555555555555555555555555555555555555555555"
xz_url = "https://static.rust-lang.org/dist/2026-10-23/rustc-1.99.0-x86_64-unknown-linux-gnu.tar.xz"
xz_hash = "6666666666666666666666666666666666666666666666666666666666666666"

[pkg.clippy-preview.target.x86_64-unknown-linux-gnu]
available = true
url = "https://static.rust-lang.org/dist/2026-10-23/clippy-1.99.0-x86_64-unknown-linux-gnu.tar.gz"
hash = "7777777777777777777777777777777777777777777777777777777777777777"
xz_url = "https://static.rust-lang.org/dist/2026-10-23/clippy-1.99.0-x86_64-unknown-linux-gnu.tar.xz"
xz_hash = "8888888888888888888888888888888888888888888888888888888888888888"

[pkg.rustc.target.wasm32-unknown-unknown]
available = false

[pkg.rust-src.target."*"]
available = true
url = "https://static.rust-lang.org/dist/2026-10-23/rust-src-1.99.0.tar.gz"
hash = "9999999999999999999999999999999999999999999999999999999999999999"
xz_url = "https://static.rust-lang.org/dist/2026-10-23/rust-src-1.99.0.tar.xz"
xz_hash = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
"""

# The same shape for a nightly, `2026-08-20/channel-rust-nightly.toml`: the
# archives carry `nightly` where a release carries its version.
_NIGHTLY_MANIFEST = """\
manifest-version = "2"
date = "2026-08-20"

[pkg.rust-std.target.x86_64-unknown-linux-gnu]
available = true
url = "https://static.rust-lang.org/dist/2026-08-20/rust-std-nightly-x86_64-unknown-linux-gnu.tar.gz"
hash = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
xz_url = "https://static.rust-lang.org/dist/2026-08-20/rust-std-nightly-x86_64-unknown-linux-gnu.tar.xz"
xz_hash = "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
"""

def _test_parse_manifest_requested_targets_in_the_requested_format(env):
    """The result is keyed like `known_shas.bzl`: the archive's file name, in the format the URL templates download."""
    env.expect.that_dict(
        parse_manifest(_STABLE_MANIFEST, ["x86_64-unknown-linux-gnu"], None, ".tar.gz"),
    ).contains_exactly({
        "clippy-1.99.0-x86_64-unknown-linux-gnu.tar.gz": "7777777777777777777777777777777777777777777777777777777777777777",
        "rust-src-1.99.0.tar.gz": "9999999999999999999999999999999999999999999999999999999999999999",
        "rust-std-1.99.0-x86_64-unknown-linux-gnu.tar.gz": "1111111111111111111111111111111111111111111111111111111111111111",
        "rustc-1.99.0-x86_64-unknown-linux-gnu.tar.gz": "5555555555555555555555555555555555555555555555555555555555555555",
    })

def _test_parse_manifest_xz(env):
    """Asking for `.tar.xz` reads the `xz_url`/`xz_hash` pairs instead."""
    env.expect.that_dict(
        parse_manifest(_STABLE_MANIFEST, ["aarch64-apple-darwin"], None, ".tar.xz"),
    ).contains_exactly({
        "rust-src-1.99.0.tar.xz": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "rust-std-1.99.0-aarch64-apple-darwin.tar.xz": "4444444444444444444444444444444444444444444444444444444444444444",
    })

def _test_parse_manifest_nightly(env):
    """Nightly and beta archives are keyed under their iso date, as `produce_tool_suburl` names them."""
    env.expect.that_dict(
        parse_manifest(_NIGHTLY_MANIFEST, ["x86_64-unknown-linux-gnu"], "2026-08-20", ".tar.gz"),
    ).contains_exactly({
        "2026-08-20/rust-std-nightly-x86_64-unknown-linux-gnu.tar.gz": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
    })

def _test_parse_manifest_unknown_target(env):
    """A target the release does not build for yields only the target-independent archives."""
    env.expect.that_dict(
        parse_manifest(_STABLE_MANIFEST, ["wasm32-unknown-unknown", "riscv32imc-unknown-none-elf"], None, ".tar.gz"),
    ).contains_exactly({
        "rust-src-1.99.0.tar.gz": "9999999999999999999999999999999999999999999999999999999999999999",
    })

def _test_manifest_urls(env):
    """The manifest lives next to the archives on each mirror; templates without a `{}` are skipped."""
    env.expect.that_collection(
        manifest_urls(["https://static.rust-lang.org/dist/{}.tar.gz"], "1.99.0", None),
    ).contains_exactly([
        "https://static.rust-lang.org/dist/channel-rust-1.99.0.toml",
    ]).in_order()
    env.expect.that_collection(
        manifest_urls(
            ["https://mirror.example.com/rust/{}.tar.xz", "https://example.com/not-a-template", "https://static.rust-lang.org/dist/{}.tar.xz"],
            "nightly",
            "2026-08-20",
        ),
    ).contains_exactly([
        "https://mirror.example.com/rust/2026-08-20/channel-rust-nightly.toml",
        "https://static.rust-lang.org/dist/2026-08-20/channel-rust-nightly.toml",
    ]).in_order()

def _test_archive_extension(env):
    """The first template decides the format; the default is `.tar.gz`."""
    env.expect.that_str(archive_extension([])).equals(".tar.gz")
    env.expect.that_str(archive_extension(["https://static.rust-lang.org/dist/{}.tar.gz"])).equals(".tar.gz")
    env.expect.that_str(archive_extension(["https://static.rust-lang.org/dist/{}.tar.xz"])).equals(".tar.xz")

def _test_split_version(env):
    """`versions` entries are a release, or a channel with an iso date."""
    for version, expected in (
        ("1.99.0", ["1.99.0", None]),
        ("nightly/2026-08-20", ["nightly", "2026-08-20"]),
        ("beta/2026-08-20", ["beta", "2026-08-20"]),
        ("nightly", ["nightly", None]),
    ):
        env.expect.that_collection(list(split_version(version))).contains_exactly(expected).in_order()

def channel_manifest_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name (str): Name of the macro.
    """
    test_suite(
        name = name,
        basic_tests = [
            _test_parse_manifest_requested_targets_in_the_requested_format,
            _test_parse_manifest_xz,
            _test_parse_manifest_nightly,
            _test_parse_manifest_unknown_target,
            _test_manifest_urls,
            _test_archive_extension,
            _test_split_version,
        ],
    )
