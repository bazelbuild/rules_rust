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
# Unsupported target "data" with type "test" omitted
# Unsupported target "parse_url" with type "bench" omitted
# Unsupported target "unit" with type "test" omitted

# buildifier: leave-alone
rust_library(
    name = "url",
    crate_type = "lib",
    deps = [
        "@rules_rust_wasm_bindgen__idna__0_1_5//:idna",
        "@rules_rust_wasm_bindgen__matches__0_1_8//:matches",
        "@rules_rust_wasm_bindgen__percent_encoding__1_0_1//:percent_encoding",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "1.7.2",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
    ],
)
