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

# Unsupported target "data" with type "test" omitted
# Unsupported target "parse_url" with type "bench" omitted
# Unsupported target "unit" with type "test" omitted

rust_library(
    name = "url",
    srcs = glob(["**/*.rs"]),
    crate_features = [
    ],
    crate_root = "src/lib.rs",
    crate_type = "lib",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "1.7.2",
    deps = [
        "@raze__idna__0_1_5//:idna",
        "@raze__matches__0_1_8//:matches",
        "@raze__percent_encoding__1_0_1//:percent_encoding",
    ],
)
