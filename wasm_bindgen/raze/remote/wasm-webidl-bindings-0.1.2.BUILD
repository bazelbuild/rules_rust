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

# Unsupported target "readme_up_to_date" with type "test" omitted
# Unsupported target "tests" with type "test" omitted

rust_library(
    name = "wasm_webidl_bindings",
    srcs = glob(["**/*.rs"]),
    crate_features = [
    ],
    crate_root = "src/lib.rs",
    crate_type = "lib",
    edition = "2018",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.1.2",
    deps = [
        "@raze__failure__0_1_5//:failure",
        "@raze__id_arena__2_2_1//:id_arena",
        "@raze__leb128__0_2_4//:leb128",
        "@raze__walrus__0_8_0//:walrus",
    ],
)
