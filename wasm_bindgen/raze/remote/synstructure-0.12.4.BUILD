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
    name = "synstructure",
    crate_type = "lib",
    deps = [
        "@rules_rust_wasm_bindgen__proc_macro2__1_0_24//:proc_macro2",
        "@rules_rust_wasm_bindgen__quote__1_0_7//:quote",
        "@rules_rust_wasm_bindgen__syn__1_0_44//:syn",
        "@rules_rust_wasm_bindgen__unicode_xid__0_2_1//:unicode_xid",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2018",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.12.4",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
        "default",
        "proc-macro",
    ],
)
