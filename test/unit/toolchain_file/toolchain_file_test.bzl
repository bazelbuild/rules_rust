"""Unit tests for toolchain_file.bzl: what a rustup toolchain file says and how the `rust` extension reads it."""

load("@rules_testing//lib:test_suite.bzl", "test_suite")

# buildifier: disable=bzl-visibility
load(
    "//rust/private:toolchain_file.bzl",
    "parse_channel",
    "parse_manifest_release",
    "parse_toolchain_file",
    "resolve_channel",
    "toolchain_file_settings",
    "with_channel_version",
)

_URLS = ["https://static.rust-lang.org/dist/{}.tar.xz"]

# The file as rustup documents it, with the comments and multi-line arrays
# `taplo` and friends produce.
_TOOLCHAIN_TOML = """\
# Pinned for CI.
[toolchain]
channel = "1.99.0" # the release the team is on
components = [
    "rustfmt",
    "clippy", # trailing comma below
    "rustc-dev",
]
targets = ["wasm32-unknown-unknown", "aarch64-apple-darwin"]
profile = "minimal"
"""

# The head of `channel-rust-stable.toml`: the manifest of a release
# published under the channel's name, so `[pkg.rust]` names the release.
_STABLE_MANIFEST = """\
manifest-version = "2"
date = "2026-10-23"

[pkg.cargo]
version = "1.99.0 (abcdef012 2026-10-21)"

[pkg.rust]
version = "1.99.0 (abcdef012 2026-10-21)"

[pkg.rust.target.x86_64-unknown-linux-gnu]
available = true
url = "https://static.rust-lang.org/dist/2026-10-23/rust-1.99.0-x86_64-unknown-linux-gnu.tar.gz"
"""

_NIGHTLY_MANIFEST = """\
manifest-version = "2"
date = "2026-08-20"

[pkg.rust]
version = "1.101.0-nightly (0123abcde 2026-08-19)"
"""

def _test_parse_toolchain_file(env):
    """Every key rustup documents is accepted, comments and multi-line arrays included; `channel` and `targets` are kept."""
    spec = parse_toolchain_file(_TOOLCHAIN_TOML)
    env.expect.that_str(spec.channel).equals("1.99.0")
    env.expect.that_collection(spec.targets).contains_exactly(["wasm32-unknown-unknown", "aarch64-apple-darwin"]).in_order()

def _test_parse_toolchain_file_channel_only(env):
    """A file with nothing but a channel has no targets."""
    spec = parse_toolchain_file("[toolchain]\nchannel = \"nightly-2026-08-20\"\n")
    env.expect.that_str(spec.channel).equals("nightly-2026-08-20")
    env.expect.that_collection(spec.targets).contains_exactly([])

def _test_parse_toolchain_file_legacy(env):
    """The legacy `rust-toolchain` file is the channel on a line of its own."""
    spec = parse_toolchain_file("nightly-2026-08-20\n", "rust-toolchain")
    env.expect.that_str(spec.channel).equals("nightly-2026-08-20")
    env.expect.that_collection(spec.targets).contains_exactly([])

def _test_parse_channel(env):
    """Channels naming an exact release translate to `versions` syntax; the others need the manifest."""
    for channel, expected in (
        ("1.99.0", ["1.99.0", None, "1.99.0"]),
        ("nightly-2026-08-20", ["nightly", "2026-08-20", "nightly/2026-08-20"]),
        ("beta-2026-08-20", ["beta", "2026-08-20", "beta/2026-08-20"]),
        ("stable", ["stable", None, None]),
        ("stable-2026-10-23", ["stable", "2026-10-23", None]),
        ("beta", ["beta", None, None]),
        ("nightly", ["nightly", None, None]),
        ("1.99", ["1.99", None, None]),
    ):
        parsed = parse_channel(channel)
        env.expect.where(channel = channel).that_collection(
            [parsed.channel, parsed.iso_date, parsed.version],
        ).contains_exactly(expected).in_order()

def _test_parse_manifest_release(env):
    """A release is named by `[pkg.rust]`, a nightly or beta by the manifest's date."""
    env.expect.that_str(parse_manifest_release(_STABLE_MANIFEST, "stable", "test")).equals("1.99.0")
    env.expect.that_str(parse_manifest_release(_STABLE_MANIFEST, "1.99", "test")).equals("1.99.0")
    env.expect.that_str(parse_manifest_release(_NIGHTLY_MANIFEST, "nightly", "test")).equals("nightly/2026-08-20")

def _fake_module_ctx(manifest, *, toolchain_file = "", download_succeeds = True):
    """A stand-in for `module_ctx` with what the toolchain file code touches: `download` and `read`.

    `read` returns the toolchain file for a `Label` and the manifest for a
    downloaded path. Downloads are recorded in the returned `downloads` list.
    """
    downloads = []

    def download(*, url, **_kwargs):
        downloads.append(url)
        return struct(success = download_succeeds)

    def read(path):
        if type(path) == "Label":
            return toolchain_file
        return manifest

    return struct(
        download = download,
        read = read,
        downloads = downloads,
    )

def _test_resolve_channel_exact_release(env):
    """An exact release needs no manifest."""
    ctx = _fake_module_ctx("")
    resolved = resolve_channel(ctx, "nightly-2026-08-20", urls = _URLS, facts = {})
    env.expect.that_str(resolved.version).equals("nightly/2026-08-20")
    env.expect.that_bool(resolved.manifest == None).equals(True)
    env.expect.that_collection(ctx.downloads).contains_exactly([])

def _test_resolve_channel_from_manifest(env):
    """`stable` is whatever `channel-rust-stable.toml` describes, and the manifest is kept for the hashes."""
    ctx = _fake_module_ctx(_STABLE_MANIFEST)
    resolved = resolve_channel(ctx, "stable", urls = _URLS, facts = {})
    env.expect.that_str(resolved.version).equals("1.99.0")
    env.expect.that_str(resolved.manifest).equals(_STABLE_MANIFEST)
    env.expect.that_collection(ctx.downloads).contains_exactly([
        ["https://static.rust-lang.org/dist/channel-rust-stable.toml"],
    ])

def _test_resolve_channel_dated_and_minor(env):
    """A dated channel reads the archived manifest, a `1.99` channel the minor's."""
    ctx = _fake_module_ctx(_STABLE_MANIFEST)
    env.expect.that_str(resolve_channel(ctx, "stable-2026-10-23", urls = _URLS, facts = None).version).equals("1.99.0")
    env.expect.that_str(resolve_channel(ctx, "1.99", urls = _URLS, facts = None).version).equals("1.99.0")
    env.expect.that_collection(ctx.downloads).contains_exactly([
        ["https://static.rust-lang.org/dist/2026-10-23/channel-rust-stable.toml"],
        ["https://static.rust-lang.org/dist/channel-rust-1.99.toml"],
    ]).in_order()

def _test_resolve_channel_recorded(env):
    """A channel the lockfile already resolved is not resolved again."""
    ctx = _fake_module_ctx(_STABLE_MANIFEST)
    resolved = resolve_channel(ctx, "stable", urls = _URLS, facts = {"stable": "1.98.0"})
    env.expect.that_str(resolved.version).equals("1.98.0")
    env.expect.that_collection(ctx.downloads).contains_exactly([])

def _test_with_channel_version(env):
    """The file's release takes the place of the entry of its channel and leaves the others."""
    env.expect.that_collection(
        with_channel_version(["1.98.0", "nightly/2026-01-01"], "1.99.0"),
    ).contains_exactly(["nightly/2026-01-01", "1.99.0"]).in_order()
    env.expect.that_collection(
        with_channel_version(["1.98.0", "nightly/2026-01-01"], "nightly/2026-08-20"),
    ).contains_exactly(["1.98.0", "nightly/2026-08-20"]).in_order()
    env.expect.that_collection(
        with_channel_version(["1.98.0"], "beta/2026-08-20"),
    ).contains_exactly(["1.98.0", "beta/2026-08-20"]).in_order()
    env.expect.that_collection(
        with_channel_version([], "1.99.0"),
    ).contains_exactly(["1.99.0"])

def _test_toolchain_file_settings(env):
    """The file's channel and targets land in the tag's settings, merged with what the tag says."""
    ctx = _fake_module_ctx(_STABLE_MANIFEST, toolchain_file = _TOOLCHAIN_TOML)
    channels = {}
    settings = toolchain_file_settings(
        ctx,
        Label("//:rust-toolchain.toml"),
        versions = ["1.98.0", "nightly/2026-01-01"],
        extra_target_triples = ["wasm32-wasip1", "wasm32-unknown-unknown"],
        urls = _URLS,
        facts = {},
        channels = channels,
    )
    env.expect.that_collection(settings.versions).contains_exactly(["nightly/2026-01-01", "1.99.0"]).in_order()
    env.expect.that_collection(settings.extra_target_triples).contains_exactly(
        ["wasm32-wasip1", "wasm32-unknown-unknown", "aarch64-apple-darwin"],
    ).in_order()
    env.expect.that_dict(settings.manifests).contains_exactly({})
    env.expect.that_dict(channels).contains_exactly({})
    env.expect.that_collection(ctx.downloads).contains_exactly([])

def _test_toolchain_file_settings_records_the_channel(env):
    """A floating channel is resolved once, recorded as a fact and its manifest handed on for the hashes."""
    ctx = _fake_module_ctx(_STABLE_MANIFEST, toolchain_file = "stable\n")
    channels = {}
    settings = toolchain_file_settings(
        ctx,
        Label("//:rust-toolchain"),
        versions = ["1.98.0"],
        extra_target_triples = [],
        urls = _URLS,
        facts = {},
        channels = channels,
    )
    env.expect.that_collection(settings.versions).contains_exactly(["1.99.0"])
    env.expect.that_dict(settings.manifests).contains_exactly({"1.99.0": _STABLE_MANIFEST})
    env.expect.that_dict(channels).contains_exactly({"stable": "1.99.0"})

def toolchain_file_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name (str): Name of the macro.
    """
    test_suite(
        name = name,
        basic_tests = [
            _test_parse_toolchain_file,
            _test_parse_toolchain_file_channel_only,
            _test_parse_toolchain_file_legacy,
            _test_parse_channel,
            _test_parse_manifest_release,
            _test_resolve_channel_exact_release,
            _test_resolve_channel_from_manifest,
            _test_resolve_channel_dated_and_minor,
            _test_resolve_channel_recorded,
            _test_with_channel_version,
            _test_toolchain_file_settings,
            _test_toolchain_file_settings_records_the_channel,
        ],
    )
