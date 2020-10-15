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
    "notice",  # MIT from expression "MIT OR Apache-2.0"
])

# Generated targets

# buildifier: leave-alone
rust_library(
    name = "walrus_macro",
    crate_type = "proc-macro",
    deps = [
        "@rules_rust_wasm_bindgen__heck__0_3_1//:heck",
        "@rules_rust_wasm_bindgen__proc_macro2__0_4_30//:proc_macro2",
        "@rules_rust_wasm_bindgen__quote__0_6_13//:quote",
        "@rules_rust_wasm_bindgen__syn__0_15_44//:syn",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2018",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.8.0",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
    ],
)
