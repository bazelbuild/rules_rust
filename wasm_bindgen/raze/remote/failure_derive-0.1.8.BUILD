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
# Unsupported target "backtrace" with type "test" omitted
# Unsupported target "build-script-build" with type "custom-build" omitted
# Unsupported target "custom_type_bounds" with type "test" omitted

# buildifier: leave-alone
rust_library(
    name = "failure_derive",
    crate_type = "proc-macro",
    deps = [
        "@rules_rust_wasm_bindgen__proc_macro2__1_0_24//:proc_macro2",
        "@rules_rust_wasm_bindgen__quote__1_0_7//:quote",
        "@rules_rust_wasm_bindgen__syn__1_0_44//:syn",
        "@rules_rust_wasm_bindgen__synstructure__0_12_4//:synstructure",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.1.8",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
    ],
)
# Unsupported target "no_derive_display" with type "test" omitted
# Unsupported target "tests" with type "test" omitted
# Unsupported target "wraps" with type "test" omitted
