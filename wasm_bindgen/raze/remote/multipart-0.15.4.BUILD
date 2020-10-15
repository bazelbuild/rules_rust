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

# buildifier: leave-alone
rust_binary(
    # Prefix bin name to disambiguate from (probable) collision with lib name
    # N.B.: The exact form of this is subject to change.
    name = "cargo_bin_form_test",
    deps = [
        # Binaries get an implicit dependency on their crate's lib
        ":multipart",
        "@rules_rust_wasm_bindgen__buf_redux__0_8_4//:buf_redux",
        "@rules_rust_wasm_bindgen__httparse__1_3_4//:httparse",
        "@rules_rust_wasm_bindgen__log__0_4_11//:log",
        "@rules_rust_wasm_bindgen__mime__0_2_6//:mime",
        "@rules_rust_wasm_bindgen__mime_guess__1_8_8//:mime_guess",
        "@rules_rust_wasm_bindgen__quick_error__1_2_3//:quick_error",
        "@rules_rust_wasm_bindgen__rand__0_4_6//:rand",
        "@rules_rust_wasm_bindgen__safemem__0_3_3//:safemem",
        "@rules_rust_wasm_bindgen__tempdir__0_3_7//:tempdir",
        "@rules_rust_wasm_bindgen__twoway__0_1_8//:twoway",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/bin/form_test.rs",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.15.4",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
        "buf_redux",
        "httparse",
        "quick-error",
        "safemem",
        "server",
        "twoway",
    ],
)
# Unsupported target "hyper_client" with type "example" omitted
# Unsupported target "hyper_reqbuilder" with type "example" omitted
# Unsupported target "hyper_server" with type "example" omitted
# Unsupported target "iron" with type "example" omitted
# Unsupported target "iron_intercept" with type "example" omitted

# buildifier: leave-alone
rust_library(
    name = "multipart",
    crate_type = "lib",
    deps = [
        "@rules_rust_wasm_bindgen__buf_redux__0_8_4//:buf_redux",
        "@rules_rust_wasm_bindgen__httparse__1_3_4//:httparse",
        "@rules_rust_wasm_bindgen__log__0_4_11//:log",
        "@rules_rust_wasm_bindgen__mime__0_2_6//:mime",
        "@rules_rust_wasm_bindgen__mime_guess__1_8_8//:mime_guess",
        "@rules_rust_wasm_bindgen__quick_error__1_2_3//:quick_error",
        "@rules_rust_wasm_bindgen__rand__0_4_6//:rand",
        "@rules_rust_wasm_bindgen__safemem__0_3_3//:safemem",
        "@rules_rust_wasm_bindgen__tempdir__0_3_7//:tempdir",
        "@rules_rust_wasm_bindgen__twoway__0_1_8//:twoway",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.15.4",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
        "buf_redux",
        "httparse",
        "quick-error",
        "safemem",
        "server",
        "twoway",
    ],
)
# Unsupported target "nickel" with type "example" omitted
# Unsupported target "rocket" with type "example" omitted
# Unsupported target "tiny_http" with type "example" omitted
