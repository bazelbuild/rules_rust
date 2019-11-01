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

# Unsupported target "alloc_with" with type "test" omitted
# Unsupported target "benches" with type "bench" omitted

rust_library(
    name = "bumpalo",
    srcs = glob(["**/*.rs"]),
    crate_features = [
        "collections",
        "default",
        "std",
    ],
    crate_root = "src/lib.rs",
    crate_type = "lib",
    edition = "2018",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "2.4.3",
    deps = [
    ],
)

# Unsupported target "quickchecks" with type "test" omitted
# Unsupported target "readme_up_to_date" with type "test" omitted
# Unsupported target "string" with type "test" omitted
# Unsupported target "tests" with type "test" omitted
# Unsupported target "vec" with type "test" omitted
