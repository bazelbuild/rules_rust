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
# Unsupported target "all" with type "test" omitted

# buildifier: leave-alone
rust_library(
    name = "wasm_bindgen_externref_xform",
    crate_type = "lib",
    deps = [
        "@rules_rust_wasm_bindgen__anyhow__1_0_32//:anyhow",
        "@rules_rust_wasm_bindgen__walrus__0_18_0//:walrus",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2018",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.2.68",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
    ],
)
