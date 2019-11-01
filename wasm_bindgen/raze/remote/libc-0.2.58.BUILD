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
    "restricted",  # "MIT OR Apache-2.0"
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_binary",
    "rust_library",
    "rust_test",
)

# Unsupported target "build-script-build" with type "custom-build" omitted

rust_library(
    name = "libc",
    srcs = glob(["**/*.rs"]),
    crate_features = [
        "default",
        "std",
    ],
    crate_root = "src/lib.rs",
    crate_type = "lib",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
        "--cfg=libc_core_cvoid",
        "--cfg=libc_priv_mod_use",
        "--cfg=libc_union",
        "--cfg=libc_const_size_of",
        "--cfg=libc_align",
        "--cfg=libc_packagedN",
    ],
    version = "0.2.58",
    deps = [
    ],
)
