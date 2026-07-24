"""Unit tests for `build_strip_levels`, backing the `rust.strip_level_select` tag."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")

# buildifier: disable=bzl-visibility
load("//rust/private:strip_level.bzl", "build_strip_levels")

# Mirrors the `strip_level_select` tag's attribute defaults, which match the
# `rust_toolchain` strip level defaults.
def _select(triples, dbg = "none", fastbuild = "none", opt = "debuginfo"):
    return struct(triples = triples, dbg = dbg, fastbuild = fastbuild, opt = opt)

_DEFAULT = {"dbg": "none", "fastbuild": "none", "opt": "none"}

def _build_strip_levels_test_impl(ctx):
    env = unittest.begin(ctx)

    # No selects and no default: nothing is configured.
    asserts.equals(
        env,
        {},
        build_strip_levels(
            strip_level_selects = [],
            default_strip_level = {},
            triples = ["x86_64-unknown-linux-gnu", "aarch64-apple-darwin"],
        ),
    )

    # The default is applied to every triple when there are no selects.
    asserts.equals(
        env,
        {
            "aarch64-apple-darwin": _DEFAULT,
            "x86_64-unknown-linux-gnu": _DEFAULT,
        },
        build_strip_levels(
            strip_level_selects = [],
            default_strip_level = _DEFAULT,
            triples = ["x86_64-unknown-linux-gnu", "aarch64-apple-darwin"],
        ),
    )

    # A matching select overrides the default; unmatched triples keep the default.
    asserts.equals(
        env,
        {
            "aarch64-apple-darwin": _DEFAULT,
            "x86_64-unknown-linux-gnu": {"dbg": "none", "fastbuild": "none", "opt": "symbols"},
        },
        build_strip_levels(
            strip_level_selects = [
                _select(["x86_64-unknown-linux-gnu"], opt = "symbols"),
            ],
            default_strip_level = _DEFAULT,
            triples = ["x86_64-unknown-linux-gnu", "aarch64-apple-darwin"],
        ),
    )

    # A select applies even when there is no default for the other triples.
    asserts.equals(
        env,
        {"x86_64-unknown-linux-gnu": {"dbg": "none", "fastbuild": "none", "opt": "symbols"}},
        build_strip_levels(
            strip_level_selects = [
                _select(["x86_64-unknown-linux-gnu"], opt = "symbols"),
            ],
            default_strip_level = {},
            triples = ["x86_64-unknown-linux-gnu", "aarch64-apple-darwin"],
        ),
    )

    # One select can target multiple triples, and selects for triples outside the
    # default triple set are still honored.
    selected = {"dbg": "none", "fastbuild": "none", "opt": "symbols"}
    asserts.equals(
        env,
        {
            "aarch64-apple-darwin": selected,
            "wasm32-unknown-unknown": selected,
            "x86_64-unknown-linux-gnu": selected,
        },
        build_strip_levels(
            strip_level_selects = [
                _select(
                    ["x86_64-unknown-linux-gnu", "aarch64-apple-darwin", "wasm32-unknown-unknown"],
                    opt = "symbols",
                ),
            ],
            default_strip_level = {},
            triples = ["x86_64-unknown-linux-gnu", "aarch64-apple-darwin"],
        ),
    )

    return unittest.end(env)

build_strip_levels_test = unittest.make(_build_strip_levels_test_impl)

def strip_level_select_test_suite(name):
    """Unit tests for `build_strip_levels`.

    Args:
        name: the test suite name
    """
    unittest.suite(
        name,
        build_strip_levels_test,
    )
