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

# buildifier: leave-alone
rust_library(
    name = "miow",
    crate_type = "lib",
    deps = [
        "@rules_rust_proto__kernel32_sys__0_2_2//:kernel32_sys",
        "@rules_rust_proto__net2__0_2_33//:net2",
        "@rules_rust_proto__winapi__0_2_8//:winapi",
        "@rules_rust_proto__ws2_32_sys__0_2_1//:ws2_32_sys",
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
