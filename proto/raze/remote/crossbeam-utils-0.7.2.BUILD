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
    "notice",  # MIT from expression "MIT OR Apache-2.0"
])

# Generated targets
# Unsupported target "atomic_cell" with type "bench" omitted
# Unsupported target "atomic_cell" with type "test" omitted
# Unsupported target "build-script-build" with type "custom-build" omitted
# Unsupported target "cache_padded" with type "test" omitted

# buildifier: leave-alone
rust_library(
    name = "crossbeam_utils",
    crate_type = "lib",
    deps = [
        "@rules_rust_proto__cfg_if__0_1_10//:cfg_if",
        "@rules_rust_proto__lazy_static__1_4_0//:lazy_static",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.7.2",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
        "default",
        "lazy_static",
        "std",
    ],
)
# Unsupported target "parker" with type "test" omitted
# Unsupported target "sharded_lock" with type "test" omitted
# Unsupported target "thread" with type "test" omitted
# Unsupported target "wait_group" with type "test" omitted
