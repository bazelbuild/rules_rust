"""Deprecated, use `:extensions.bzl`."""

load(":extensions.bzl", _crate = "crate")

# buildifier: disable=print
print(
    "\nWARNING: @rules_rust//crate_universe:extension.bzl is deprecated and will be removed in a future release. " +
    "Load `crate` from @rules_rust//crate_universe:extensions.bzl instead.",
)

crate = _crate
