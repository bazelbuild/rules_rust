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

# Unsupported target "benches" with type "bench" omitted
# Unsupported target "parse" with type "example" omitted
# Unsupported target "round-trip" with type "example" omitted

rust_library(
    name = "walrus",
    srcs = glob(["**/*.rs"]),
    crate_features = [
    ],
    crate_root = "src/lib.rs",
    crate_type = "lib",
    edition = "2018",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.8.0",
    deps = [
        "@raze__failure__0_1_5//:failure",
        "@raze__id_arena__2_2_1//:id_arena",
        "@raze__leb128__0_2_4//:leb128",
        "@raze__log__0_4_6//:log",
        "@raze__rayon__1_1_0//:rayon",
        "@raze__wasmparser__0_30_0//:wasmparser",
    ],
    proc_macro_deps = [
        "@raze__walrus_macro__0_8_0//:walrus_macro",
    ],
)
