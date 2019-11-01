"""
cargo-raze crate build file.

DO NOT EDIT! Replaced on runs of cargo-raze
"""

package(default_visibility = [
    # Public for visibility by "@raze__crate__version//" targets.
    #
    # Prefer access through "//proto/raze", which limits external
    # visibility to explicit Cargo.toml dependencies.
    "//visibility:public",
])

licenses([
    "restricted",  # "BSD-2-Clause"
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_binary",
    "rust_library",
    "rust_test",
)

rust_library(
    name = "cloudabi",
    srcs = glob(["**/*.rs"]),
    crate_features = [
        "bitflags",
        "default",
    ],
    crate_root = "cloudabi.rs",
    crate_type = "lib",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.0.3",
    deps = [
        "@raze__bitflags__1_0_4//:bitflags",
    ],
)
