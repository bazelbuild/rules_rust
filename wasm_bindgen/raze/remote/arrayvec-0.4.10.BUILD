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

# Unsupported target "arraystring" with type "bench" omitted

rust_library(
    name = "arrayvec",
    srcs = glob(["**/*.rs"]),
    crate_features = [
    ],
    crate_root = "src/lib.rs",
    crate_type = "lib",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.4.10",
    deps = [
        "@raze__nodrop__0_1_13//:nodrop",
    ],
)

# Unsupported target "build-script-build" with type "custom-build" omitted
# Unsupported target "extend" with type "bench" omitted
# Unsupported target "serde" with type "test" omitted
# Unsupported target "tests" with type "test" omitted
