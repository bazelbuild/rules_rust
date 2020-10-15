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
# Unsupported target "case_tree" with type "example" omitted

# buildifier: leave-alone
rust_library(
    name = "predicates",
    crate_type = "lib",
    deps = [
        "@rules_rust_wasm_bindgen__difference__2_0_0//:difference",
        "@rules_rust_wasm_bindgen__float_cmp__0_8_0//:float_cmp",
        "@rules_rust_wasm_bindgen__normalize_line_endings__0_3_0//:normalize_line_endings",
        "@rules_rust_wasm_bindgen__predicates_core__1_0_0//:predicates_core",
        "@rules_rust_wasm_bindgen__regex__1_4_1//:regex",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2018",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "1.0.5",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
        "default",
        "difference",
        "float-cmp",
        "normalize-line-endings",
        "regex",
    ],
)
