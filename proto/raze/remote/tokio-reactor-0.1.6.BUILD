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
    "notice",  # "MIT"
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_binary",
    "rust_library",
    "rust_test",
)

# Unsupported target "basic" with type "bench" omitted

rust_library(
    name = "tokio_reactor",
    srcs = glob(["**/*.rs"]),
    crate_features = [
    ],
    crate_root = "src/lib.rs",
    crate_type = "lib",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.1.6",
    deps = [
        "@raze__crossbeam_utils__0_5_0//:crossbeam_utils",
        "@raze__futures__0_1_25//:futures",
        "@raze__lazy_static__1_2_0//:lazy_static",
        "@raze__log__0_4_6//:log",
        "@raze__mio__0_6_16//:mio",
        "@raze__num_cpus__1_8_0//:num_cpus",
        "@raze__parking_lot__0_6_4//:parking_lot",
        "@raze__slab__0_4_1//:slab",
        "@raze__tokio_executor__0_1_5//:tokio_executor",
        "@raze__tokio_io__0_1_10//:tokio_io",
    ],
)
