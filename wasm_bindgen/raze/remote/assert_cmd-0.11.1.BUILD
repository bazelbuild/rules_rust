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
    "notice",  # MIT from expression "MIT OR Apache-2.0"
])

# Generated targets
# Unsupported target "assert" with type "test" omitted

# buildifier: leave-alone
rust_library(
    name = "assert_cmd",
    crate_type = "lib",
    deps = [
        "@rules_rust_wasm_bindgen__escargot__0_4_0//:escargot",
        "@rules_rust_wasm_bindgen__predicates__1_0_5//:predicates",
        "@rules_rust_wasm_bindgen__predicates_core__1_0_0//:predicates_core",
        "@rules_rust_wasm_bindgen__predicates_tree__1_0_0//:predicates_tree",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.11.1",
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
    name = "cargo_bin_bin_fixture",
    deps = [
        # Binaries get an implicit dependency on their crate's lib
        ":assert_cmd",
        "@rules_rust_wasm_bindgen__escargot__0_4_0//:escargot",
        "@rules_rust_wasm_bindgen__predicates__1_0_5//:predicates",
        "@rules_rust_wasm_bindgen__predicates_core__1_0_0//:predicates_core",
        "@rules_rust_wasm_bindgen__predicates_tree__1_0_0//:predicates_tree",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/bin/bin_fixture.rs",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.11.1",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
    ],
)
# Unsupported target "cargo" with type "test" omitted
# Unsupported target "docmatic" with type "test" omitted
# Unsupported target "example_fixture" with type "example" omitted
# Unsupported target "examples" with type "test" omitted
