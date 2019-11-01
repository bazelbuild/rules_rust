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
    "notice",  # "MIT"
    "unencumbered",  # "Unlicense"
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_binary",
    "rust_library",
    "rust_test",
)

# Unsupported target "cargo" with type "example" omitted
# Unsupported target "cp" with type "example" omitted
# Unsupported target "decode" with type "example" omitted

rust_library(
    name = "docopt",
    srcs = glob(["**/*.rs"]),
    crate_features = [
    ],
    crate_root = "src/lib.rs",
    crate_type = "lib",
    edition = "2018",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "1.1.0",
    deps = [
        "@raze__lazy_static__1_3_0//:lazy_static",
        "@raze__regex__1_1_7//:regex",
        "@raze__serde__1_0_94//:serde",
        "@raze__strsim__0_9_2//:strsim",
    ],
)

rust_binary(
    # Prefix bin name to disambiguate from (probable) collision with lib name
    # N.B.: The exact form of this is subject to change.
    name = "cargo_bin_docopt_wordlist",
    srcs = glob(["**/*.rs"]),
    crate_features = [
    ],
    crate_root = "src/wordlist.rs",
    edition = "2018",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "1.1.0",
    deps = [
        # Binaries get an implicit dependency on their crate's lib
        ":docopt",
        "@raze__lazy_static__1_3_0//:lazy_static",
        "@raze__regex__1_1_7//:regex",
        "@raze__serde__1_0_94//:serde",
        "@raze__strsim__0_9_2//:strsim",
    ],
)

# Unsupported target "hashmap" with type "example" omitted
# Unsupported target "optional_command" with type "example" omitted
# Unsupported target "verbose_multiple" with type "example" omitted
