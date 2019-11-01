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

# Unsupported target "namedtempfile" with type "test" omitted
# Unsupported target "spooled" with type "test" omitted
# Unsupported target "tempdir" with type "test" omitted

rust_library(
    name = "tempfile",
    srcs = glob(["**/*.rs"]),
    crate_features = [
    ],
    crate_root = "src/lib.rs",
    crate_type = "lib",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "3.0.8",
    deps = [
        "@raze__cfg_if__0_1_9//:cfg_if",
        "@raze__libc__0_2_58//:libc",
        "@raze__rand__0_6_5//:rand",
        "@raze__remove_dir_all__0_5_2//:remove_dir_all",
    ],
)

# Unsupported target "tempfile" with type "test" omitted
