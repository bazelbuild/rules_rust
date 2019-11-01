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
    name = "base64",
    srcs = glob(["**/*.rs"]),
    crate_features = [
    ],
    crate_root = "src/lib.rs",
    crate_type = "lib",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.9.3",
    deps = [
        "@raze__byteorder__1_3_2//:byteorder",
        "@raze__safemem__0_3_0//:safemem",
    ],
)

# Unsupported target "benchmarks" with type "bench" omitted
# Unsupported target "decode" with type "test" omitted
# Unsupported target "encode" with type "test" omitted
# Unsupported target "helpers" with type "test" omitted
# Unsupported target "make_tables" with type "example" omitted
# Unsupported target "tests" with type "test" omitted
