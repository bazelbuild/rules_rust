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
    "notice",  # MIT from expression "MIT OR (Apache-2.0 AND BSD-2-Clause)"
])

# Generated targets
# Unsupported target "array_queue" with type "test" omitted

# buildifier: leave-alone
rust_library(
    name = "crossbeam_queue",
    crate_type = "lib",
    deps = [
        "@rules_rust_proto__cfg_if__0_1_10//:cfg_if",
        "@rules_rust_proto__crossbeam_utils__0_7_2//:crossbeam_utils",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.2.1",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
        "default",
        "std",
    ],
)
# Unsupported target "seg_queue" with type "test" omitted
