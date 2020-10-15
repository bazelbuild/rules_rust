"""
@generated
cargo-raze crate build file.

DO NOT EDIT! Replaced on runs of cargo-raze
"""

# buildifier: disable=load
load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_binary",
    "rust_library",
    "rust_test",
)

# buildifier: disable=load
load("@bazel_skylib//lib:selects.bzl", "selects")

package(default_visibility = [
    # Public for visibility by "@raze__crate__version//" targets.
    #
    # Prefer access through "//wasm_bindgen/raze", which limits external
    # visibility to explicit Cargo.toml dependencies.
    "//visibility:public",
])

licenses([
    "unencumbered",  # Unlicense from expression "Unlicense OR MIT"
])

# Generated targets
# Unsupported target "cargo" with type "example" omitted
# Unsupported target "cp" with type "example" omitted
# Unsupported target "decode" with type "example" omitted

# buildifier: leave-alone
rust_library(
    name = "docopt",
    crate_type = "lib",
    deps = [
        "@rules_rust_wasm_bindgen__lazy_static__1_4_0//:lazy_static",
        "@rules_rust_wasm_bindgen__regex__1_4_1//:regex",
        "@rules_rust_wasm_bindgen__serde__1_0_116//:serde",
        "@rules_rust_wasm_bindgen__strsim__0_9_3//:strsim",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2018",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "1.1.0",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
    ],
)

# buildifier: leave-alone
rust_binary(
    # Prefix bin name to disambiguate from (probable) collision with lib name
    # N.B.: The exact form of this is subject to change.
    name = "cargo_bin_docopt_wordlist",
    deps = [
        # Binaries get an implicit dependency on their crate's lib
        ":docopt",
        "@rules_rust_wasm_bindgen__lazy_static__1_4_0//:lazy_static",
        "@rules_rust_wasm_bindgen__regex__1_4_1//:regex",
        "@rules_rust_wasm_bindgen__serde__1_0_116//:serde",
        "@rules_rust_wasm_bindgen__strsim__0_9_3//:strsim",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/wordlist.rs",
    edition = "2018",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "1.1.0",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
    ],
)
# Unsupported target "hashmap" with type "example" omitted
# Unsupported target "optional_command" with type "example" omitted
# Unsupported target "verbose_multiple" with type "example" omitted
