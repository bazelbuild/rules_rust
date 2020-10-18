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
# Unsupported target "interface-types" with type "test" omitted
# Unsupported target "reference" with type "test" omitted

# buildifier: leave-alone
rust_binary(
    # Prefix bin name to disambiguate from (probable) collision with lib name
    # N.B.: The exact form of this is subject to change.
    name = "cargo_bin_wasm_bindgen",
    deps = [
        "@rules_rust_wasm_bindgen__anyhow__1_0_32//:anyhow",
        "@rules_rust_wasm_bindgen__curl__0_4_33//:curl",
        "@rules_rust_wasm_bindgen__docopt__1_1_0//:docopt",
        "@rules_rust_wasm_bindgen__env_logger__0_7_1//:env_logger",
        "@rules_rust_wasm_bindgen__log__0_4_11//:log",
        "@rules_rust_wasm_bindgen__rouille__3_0_0//:rouille",
        "@rules_rust_wasm_bindgen__serde__1_0_115//:serde",
        "@rules_rust_wasm_bindgen__serde_json__1_0_57//:serde_json",
        "@rules_rust_wasm_bindgen__walrus__0_18_0//:walrus",
        "@rules_rust_wasm_bindgen__wasm_bindgen_cli_support__0_2_68//:wasm_bindgen_cli_support",
        "@rules_rust_wasm_bindgen__wasm_bindgen_shared__0_2_68//:wasm_bindgen_shared",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/bin/wasm-bindgen.rs",
    edition = "2018",
    proc_macro_deps = [
        "@rules_rust_wasm_bindgen__serde_derive__1_0_115//:serde_derive",
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.2.68",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
    ],
)
# Unsupported target "wasm-bindgen" with type "test" omitted

# buildifier: leave-alone
rust_binary(
    # Prefix bin name to disambiguate from (probable) collision with lib name
    # N.B.: The exact form of this is subject to change.
    name = "cargo_bin_wasm_bindgen_test_runner",
    deps = [
        "@rules_rust_wasm_bindgen__anyhow__1_0_32//:anyhow",
        "@rules_rust_wasm_bindgen__curl__0_4_33//:curl",
        "@rules_rust_wasm_bindgen__docopt__1_1_0//:docopt",
        "@rules_rust_wasm_bindgen__env_logger__0_7_1//:env_logger",
        "@rules_rust_wasm_bindgen__log__0_4_11//:log",
        "@rules_rust_wasm_bindgen__rouille__3_0_0//:rouille",
        "@rules_rust_wasm_bindgen__serde__1_0_115//:serde",
        "@rules_rust_wasm_bindgen__serde_json__1_0_57//:serde_json",
        "@rules_rust_wasm_bindgen__walrus__0_18_0//:walrus",
        "@rules_rust_wasm_bindgen__wasm_bindgen_cli_support__0_2_68//:wasm_bindgen_cli_support",
        "@rules_rust_wasm_bindgen__wasm_bindgen_shared__0_2_68//:wasm_bindgen_shared",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/bin/wasm-bindgen-test-runner/main.rs",
    edition = "2018",
    proc_macro_deps = [
        "@rules_rust_wasm_bindgen__serde_derive__1_0_115//:serde_derive",
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.2.68",
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
    name = "cargo_bin_wasm2es6js",
    deps = [
        "@rules_rust_wasm_bindgen__anyhow__1_0_32//:anyhow",
        "@rules_rust_wasm_bindgen__curl__0_4_33//:curl",
        "@rules_rust_wasm_bindgen__docopt__1_1_0//:docopt",
        "@rules_rust_wasm_bindgen__env_logger__0_7_1//:env_logger",
        "@rules_rust_wasm_bindgen__log__0_4_11//:log",
        "@rules_rust_wasm_bindgen__rouille__3_0_0//:rouille",
        "@rules_rust_wasm_bindgen__serde__1_0_115//:serde",
        "@rules_rust_wasm_bindgen__serde_json__1_0_57//:serde_json",
        "@rules_rust_wasm_bindgen__walrus__0_18_0//:walrus",
        "@rules_rust_wasm_bindgen__wasm_bindgen_cli_support__0_2_68//:wasm_bindgen_cli_support",
        "@rules_rust_wasm_bindgen__wasm_bindgen_shared__0_2_68//:wasm_bindgen_shared",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/bin/wasm2es6js.rs",
    edition = "2018",
    proc_macro_deps = [
        "@rules_rust_wasm_bindgen__serde_derive__1_0_115//:serde_derive",
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.2.68",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
    ],
)
