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
    # Prefer access through "//wasm_bindgen/raze", which limits external
    # visibility to explicit Cargo.toml dependencies.
    "//visibility:public",
])

licenses([
    "notice",  # MIT from expression "MIT"
])

# Generated targets

# buildifier: leave-alone
rust_library(
    name = "blake2b_simd",
    crate_type = "lib",
    deps = [
        "@rules_rust_wasm_bindgen__arrayref__0_3_6//:arrayref",
        "@rules_rust_wasm_bindgen__arrayvec__0_5_1//:arrayvec",
        "@rules_rust_wasm_bindgen__constant_time_eq__0_1_5//:constant_time_eq",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2018",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.5.10",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
        "default",
        "std",
    ],
)
