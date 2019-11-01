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
    "restricted",  # "Apache-2.0 OR BSL-1.0"
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_binary",
    "rust_library",
    "rust_test",
)

# Unsupported target "bench" with type "bench" omitted
# Unsupported target "build-script-build" with type "custom-build" omitted
# Unsupported target "d2s_table_test" with type "test" omitted
# Unsupported target "d2s_test" with type "test" omitted
# Unsupported target "exhaustive" with type "test" omitted
# Unsupported target "f2s_test" with type "test" omitted

rust_library(
    name = "ryu",
    srcs = glob(["**/*.rs"]),
    crate_features = [
    ],
    crate_root = "src/lib.rs",
    crate_type = "lib",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.2.8",
    deps = [
    ],
)

# Unsupported target "upstream_benchmark" with type "example" omitted
