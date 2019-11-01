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
    name = "wasm_bindgen_cli_support",
    srcs = glob(["**/*.rs"]),
    crate_features = [
    ],
    crate_root = "src/lib.rs",
    crate_type = "lib",
    edition = "2018",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.2.48",
    deps = [
        "@raze__base64__0_9_3//:base64",
        "@raze__failure__0_1_5//:failure",
        "@raze__log__0_4_6//:log",
        "@raze__rustc_demangle__0_1_15//:rustc_demangle",
        "@raze__serde_json__1_0_39//:serde_json",
        "@raze__tempfile__3_0_8//:tempfile",
        "@raze__walrus__0_8_0//:walrus",
        "@raze__wasm_bindgen_anyref_xform__0_2_48//:wasm_bindgen_anyref_xform",
        "@raze__wasm_bindgen_shared__0_2_48//:wasm_bindgen_shared",
        "@raze__wasm_bindgen_threads_xform__0_2_48//:wasm_bindgen_threads_xform",
        "@raze__wasm_bindgen_wasm_interpreter__0_2_48//:wasm_bindgen_wasm_interpreter",
        "@raze__wasm_webidl_bindings__0_1_2//:wasm_webidl_bindings",
    ],
)
