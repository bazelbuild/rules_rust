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
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_binary",
    "rust_library",
    "rust_test",
)

# Unsupported target "build-script-build" with type "custom-build" omitted

rust_library(
    name = "curl_sys",
    srcs = glob(["**/*.rs"]),
    crate_features = [
        "openssl-sys",
        "ssl",
    ],
    crate_root = "lib.rs",
    crate_type = "lib",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.4.19",
    deps = [
        "@raze__libc__0_2_58//:libc",
        "@raze__libz_sys__1_0_25//:libz_sys",
        "@raze__openssl_sys__0_9_47//:openssl_sys",
    ],
)
