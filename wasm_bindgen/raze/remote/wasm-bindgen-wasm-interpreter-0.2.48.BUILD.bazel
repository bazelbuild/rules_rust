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
# Unsupported target "smoke" with type "test" omitted

# buildifier: leave-alone
rust_library(
    name = "wasm_bindgen_wasm_interpreter",
    crate_type = "lib",
    deps = [
        "@rules_rust_wasm_bindgen__failure__0_1_8//:failure",
        "@rules_rust_wasm_bindgen__log__0_4_11//:log",
        "@rules_rust_wasm_bindgen__walrus__0_8_0//:walrus",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2018",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.2.48",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
    ],
)
