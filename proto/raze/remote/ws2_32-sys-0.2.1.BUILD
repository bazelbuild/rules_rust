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
    "notice",  # MIT from expression "MIT"
])

# Generated targets
# Unsupported target "build-script-build" with type "custom-build" omitted

alias(
    name = "ws2_32_sys",
    actual = ":ws2_32",
    tags = [
        "cargo-raze",
        "manual",
    ],
)

# buildifier: leave-alone
rust_library(
    name = "ws2_32",
    crate_type = "lib",
    deps = [
        "@rules_rust_proto__winapi__0_2_8//:winapi",
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
    ],
)
