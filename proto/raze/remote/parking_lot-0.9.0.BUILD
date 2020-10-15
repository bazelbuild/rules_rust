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
    "notice",  # Apache-2.0 from expression "Apache-2.0 OR MIT"
])

# Generated targets
# Unsupported target "build-script-build" with type "custom-build" omitted

# buildifier: leave-alone
rust_library(
    name = "parking_lot",
    crate_type = "lib",
    deps = [
        "@rules_rust_proto__lock_api__0_3_4//:lock_api",
        "@rules_rust_proto__parking_lot_core__0_6_2//:parking_lot_core",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2018",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.9.0",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
        "default",
    ],
)
