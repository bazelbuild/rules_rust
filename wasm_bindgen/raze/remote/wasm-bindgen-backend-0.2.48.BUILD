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
  "notice", # "MIT,Apache-2.0"
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_library",
    "rust_binary",
    "rust_test",
)



rust_library(
    name = "wasm_bindgen_backend",
    crate_root = "src/lib.rs",
    crate_type = "lib",
    edition = "2018",
    srcs = glob(["**/*.rs"]),
    deps = [
        "@raze__bumpalo__2_4_3//:bumpalo",
        "@raze__lazy_static__1_3_0//:lazy_static",
        "@raze__log__0_4_6//:log",
        "@raze__proc_macro2__0_4_30//:proc_macro2",
        "@raze__quote__0_6_12//:quote",
        "@raze__syn__0_15_43//:syn",
        "@raze__wasm_bindgen_shared__0_2_48//:wasm_bindgen_shared",
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.2.48",
    crate_features = [
        "spans",
    ],
)

