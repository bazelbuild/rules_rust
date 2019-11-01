"""
cargo-raze crate build file.

DO NOT EDIT! Replaced on runs of cargo-raze
"""

package(default_visibility = [
    # Public for visibility by "@raze__crate__version//" targets.
    #
    # Prefer access through "//wasm_bindgen/raze", which limits external
    # visibility to explicit Cargo.toml dependencies.
    "//visibility:public",
])

licenses([
    "notice",  # "MIT,Apache-2.0"
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_binary",
    "rust_library",
    "rust_test",
)

rust_library(
    name = "walrus_macro",
    srcs = glob(["**/*.rs"]),
    crate_features = [
    ],
    crate_root = "src/lib.rs",
    crate_type = "proc-macro",
    edition = "2018",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.8.0",
    deps = [
        "@raze__heck__0_3_1//:heck",
        "@raze__proc_macro2__0_4_30//:proc_macro2",
        "@raze__quote__0_6_12//:quote",
        "@raze__syn__0_15_43//:syn",
    ],
)
