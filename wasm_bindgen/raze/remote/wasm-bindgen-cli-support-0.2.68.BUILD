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
    name = "wasm_bindgen_cli_support",
    crate_type = "lib",
    deps = [
        "@rules_rust_wasm_bindgen__anyhow__1_0_32//:anyhow",
        "@rules_rust_wasm_bindgen__base64__0_9_3//:base64",
        "@rules_rust_wasm_bindgen__log__0_4_11//:log",
        "@rules_rust_wasm_bindgen__rustc_demangle__0_1_16//:rustc_demangle",
        "@rules_rust_wasm_bindgen__serde_json__1_0_57//:serde_json",
        "@rules_rust_wasm_bindgen__tempfile__3_1_0//:tempfile",
        "@rules_rust_wasm_bindgen__walrus__0_18_0//:walrus",
        "@rules_rust_wasm_bindgen__wasm_bindgen_externref_xform__0_2_68//:wasm_bindgen_externref_xform",
        "@rules_rust_wasm_bindgen__wasm_bindgen_multi_value_xform__0_2_68//:wasm_bindgen_multi_value_xform",
        "@rules_rust_wasm_bindgen__wasm_bindgen_shared__0_2_68//:wasm_bindgen_shared",
        "@rules_rust_wasm_bindgen__wasm_bindgen_threads_xform__0_2_68//:wasm_bindgen_threads_xform",
        "@rules_rust_wasm_bindgen__wasm_bindgen_wasm_conventions__0_2_68//:wasm_bindgen_wasm_conventions",
        "@rules_rust_wasm_bindgen__wasm_bindgen_wasm_interpreter__0_2_68//:wasm_bindgen_wasm_interpreter",
        "@rules_rust_wasm_bindgen__wit_text__0_8_0//:wit_text",
        "@rules_rust_wasm_bindgen__wit_validator__0_2_1//:wit_validator",
        "@rules_rust_wasm_bindgen__wit_walrus__0_5_0//:wit_walrus",
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
