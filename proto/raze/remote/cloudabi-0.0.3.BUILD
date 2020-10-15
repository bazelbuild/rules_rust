"""
@generated
cargo-raze crate build file.

DO NOT EDIT! Replaced on runs of cargo-raze
"""

# buildifier: disable=load
load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_binary",
    "rust_library",
    "rust_test",
)

# buildifier: disable=load
load("@bazel_skylib//lib:selects.bzl", "selects")

package(default_visibility = [
    # Public for visibility by "@raze__crate__version//" targets.
    #
    # Prefer access through "//proto/raze", which limits external
    # visibility to explicit Cargo.toml dependencies.
    "//visibility:public",
])

licenses([
    "restricted",  # BSD-2-Clause from expression "BSD-2-Clause"
])

# Generated targets

# buildifier: leave-alone
rust_library(
    name = "cloudabi",
    crate_type = "lib",
    deps = [
        "@rules_rust_proto__bitflags__1_2_1//:bitflags",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "cloudabi.rs",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.0.3",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
        "bitflags",
        "default",
    ],
)
