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

rust_binary(
    # Prefix bin name to disambiguate from (probable) collision with lib name
    # N.B.: The exact form of this is subject to change.
    name = "cargo_bin_form_test",
    srcs = glob(["**/*.rs"]),
    crate_features = [
        "buf_redux",
        "httparse",
        "quick-error",
        "safemem",
        "server",
        "twoway",
    ],
    crate_root = "src/bin/form_test.rs",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.15.4",
    deps = [
        # Binaries get an implicit dependency on their crate's lib
        ":multipart",
        "@raze__buf_redux__0_8_1//:buf_redux",
        "@raze__httparse__1_3_3//:httparse",
        "@raze__log__0_4_6//:log",
        "@raze__mime__0_2_6//:mime",
        "@raze__mime_guess__1_8_7//:mime_guess",
        "@raze__quick_error__1_2_2//:quick_error",
        "@raze__rand__0_4_6//:rand",
        "@raze__safemem__0_3_0//:safemem",
        "@raze__tempdir__0_3_7//:tempdir",
        "@raze__twoway__0_1_8//:twoway",
    ],
)

# Unsupported target "hyper_client" with type "example" omitted
# Unsupported target "hyper_reqbuilder" with type "example" omitted
# Unsupported target "hyper_server" with type "example" omitted
# Unsupported target "iron" with type "example" omitted
# Unsupported target "iron_intercept" with type "example" omitted

rust_library(
    name = "multipart",
    srcs = glob(["**/*.rs"]),
    crate_features = [
        "buf_redux",
        "httparse",
        "quick-error",
        "safemem",
        "server",
        "twoway",
    ],
    crate_root = "src/lib.rs",
    crate_type = "lib",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.15.4",
    deps = [
        "@raze__buf_redux__0_8_1//:buf_redux",
        "@raze__httparse__1_3_3//:httparse",
        "@raze__log__0_4_6//:log",
        "@raze__mime__0_2_6//:mime",
        "@raze__mime_guess__1_8_7//:mime_guess",
        "@raze__quick_error__1_2_2//:quick_error",
        "@raze__rand__0_4_6//:rand",
        "@raze__safemem__0_3_0//:safemem",
        "@raze__tempdir__0_3_7//:tempdir",
        "@raze__twoway__0_1_8//:twoway",
    ],
)

# Unsupported target "nickel" with type "example" omitted
# Unsupported target "rocket" with type "example" omitted
# Unsupported target "tiny_http" with type "example" omitted
