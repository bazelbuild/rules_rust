"""
cargo-raze crate build file.

DO NOT EDIT! Replaced on runs of cargo-raze
"""

package(default_visibility = [
    # Public for visibility by "@raze__crate__version//" targets.
    #
    # Prefer access through "//bindgen/raze", which limits external
    # visibility to explicit Cargo.toml dependencies.
    "//visibility:public",
])

licenses([
    "notice",  # "MIT"
    "unencumbered",  # "Unlicense"
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_binary",
    "rust_library",
    "rust_test",
)

rust_binary(
    # Prefix bin name to disambiguate from (probable) collision with lib name
    # N.B.: The exact form of this is subject to change.
    name = "cargo_bin_aho_corasick_dot",
    srcs = glob(["**/*.rs"]),
    crate_features = [
    ],
    crate_root = "src/main.rs",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.6.9",
    deps = [
        # Binaries get an implicit dependency on their lib
        ":aho_corasick",
        "@raze__memchr__2_1_3//:memchr",
    ],
)

rust_library(
    name = "aho_corasick",
    srcs = glob(["**/*.rs"]),
    crate_features = [
    ],
    crate_root = "src/lib.rs",
    crate_type = "lib",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.6.9",
    deps = [
        "@raze__memchr__2_1_3//:memchr",
    ],
)

# Unsupported target "bench" with type "bench" omitted
# Unsupported target "dict-search" with type "example" omitted
