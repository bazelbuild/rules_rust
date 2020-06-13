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

rust_binary(
    # Prefix bin name to disambiguate from (probable) collision with lib name
    # N.B.: The exact form of this is subject to change.
    name = "cargo_bin_wasm_bindgen",
    srcs = glob(["**/*.rs"]),
    crate_features = [
    ],
    crate_root = "src/bin/wasm-bindgen.rs",
    edition = "2018",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.2.48",
    deps = [
        "@raze__curl__0_4_22//:curl",
        "@raze__docopt__1_1_0//:docopt",
        "@raze__env_logger__0_6_1//:env_logger",
        "@raze__failure__0_1_5//:failure",
        "@raze__log__0_4_6//:log",
        "@raze__rouille__3_0_0//:rouille",
        "@raze__serde__1_0_94//:serde",
        "@raze__serde_json__1_0_39//:serde_json",
        "@raze__walrus__0_8_0//:walrus",
        "@raze__wasm_bindgen_cli_support__0_2_48//:wasm_bindgen_cli_support",
        "@raze__wasm_bindgen_shared__0_2_48//:wasm_bindgen_shared",
    ],
    proc_macro_deps = [
        "@raze__serde_derive__1_0_94//:serde_derive",
    ],
)

# Unsupported target "wasm-bindgen" with type "test" omitted
rust_binary(
    # Prefix bin name to disambiguate from (probable) collision with lib name
    # N.B.: The exact form of this is subject to change.
    name = "cargo_bin_wasm_bindgen_test_runner",
    srcs = glob(["**/*.rs"]),
    crate_features = [
    ],
    crate_root = "src/bin/wasm-bindgen-test-runner/main.rs",
    edition = "2018",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.2.48",
    deps = [
        "@raze__curl__0_4_22//:curl",
        "@raze__docopt__1_1_0//:docopt",
        "@raze__env_logger__0_6_1//:env_logger",
        "@raze__failure__0_1_5//:failure",
        "@raze__log__0_4_6//:log",
        "@raze__rouille__3_0_0//:rouille",
        "@raze__serde__1_0_94//:serde",
        "@raze__serde_json__1_0_39//:serde_json",
        "@raze__walrus__0_8_0//:walrus",
        "@raze__wasm_bindgen_cli_support__0_2_48//:wasm_bindgen_cli_support",
        "@raze__wasm_bindgen_shared__0_2_48//:wasm_bindgen_shared",
    ],
    proc_macro_deps = [
        "@raze__serde_derive__1_0_94//:serde_derive",
    ],
)

rust_binary(
    # Prefix bin name to disambiguate from (probable) collision with lib name
    # N.B.: The exact form of this is subject to change.
    name = "cargo_bin_wasm2es6js",
    srcs = glob(["**/*.rs"]),
    crate_features = [
    ],
    crate_root = "src/bin/wasm2es6js.rs",
    edition = "2018",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.2.48",
    deps = [
        "@raze__curl__0_4_22//:curl",
        "@raze__docopt__1_1_0//:docopt",
        "@raze__env_logger__0_6_1//:env_logger",
        "@raze__failure__0_1_5//:failure",
        "@raze__log__0_4_6//:log",
        "@raze__rouille__3_0_0//:rouille",
        "@raze__serde__1_0_94//:serde",
        "@raze__serde_json__1_0_39//:serde_json",
        "@raze__walrus__0_8_0//:walrus",
        "@raze__wasm_bindgen_cli_support__0_2_48//:wasm_bindgen_cli_support",
        "@raze__wasm_bindgen_shared__0_2_48//:wasm_bindgen_shared",
    ],
    proc_macro_deps = [
        "@raze__serde_derive__1_0_94//:serde_derive",
    ],
)
