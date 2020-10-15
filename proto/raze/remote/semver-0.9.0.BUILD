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
# Unsupported target "deprecation" with type "test" omitted
# Unsupported target "regression" with type "test" omitted

# buildifier: leave-alone
rust_library(
    name = "semver",
    crate_type = "lib",
    deps = [
        "@rules_rust_proto__semver_parser__0_7_0//:semver_parser",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2015",
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
# Unsupported target "serde" with type "test" omitted
