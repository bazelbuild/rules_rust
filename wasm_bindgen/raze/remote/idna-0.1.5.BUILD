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
    name = "idna",
    crate_type = "lib",
    deps = [
        "@rules_rust_wasm_bindgen__matches__0_1_8//:matches",
        "@rules_rust_wasm_bindgen__unicode_bidi__0_3_4//:unicode_bidi",
        "@rules_rust_wasm_bindgen__unicode_normalization__0_1_13//:unicode_normalization",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.1.5",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
    ],
)
# Unsupported target "tests" with type "test" omitted
# Unsupported target "unit" with type "test" omitted
