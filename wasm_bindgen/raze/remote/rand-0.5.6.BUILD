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

# Unsupported target "bool" with type "test" omitted
# Unsupported target "distributions" with type "bench" omitted
# Unsupported target "generators" with type "bench" omitted
# Unsupported target "misc" with type "bench" omitted
# Unsupported target "monte-carlo" with type "example" omitted
# Unsupported target "monty-hall" with type "example" omitted

rust_library(
    name = "rand",
    srcs = glob(["**/*.rs"]),
    crate_features = [
        "alloc",
        "cloudabi",
        "default",
        "fuchsia-cprng",
        "libc",
        "rand_core",
        "std",
        "winapi",
    ],
    crate_root = "src/lib.rs",
    crate_type = "lib",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.5.6",
    deps = [
        "@raze__libc__0_2_58//:libc",
        "@raze__rand_core__0_3_1//:rand_core",
    ],
)
