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

# Unsupported target "build-script-main" with type "custom-build" omitted

rust_library(
    name = "openssl_sys",
    srcs = glob(["**/*.rs"]),
    crate_features = [
    ],
    crate_root = "src/lib.rs",
    crate_type = "lib",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
        "--cfg=ossl101",
        "--cfg=ossl102",
        "--cfg=ossl102f",
        "--cfg=ossl102h",
        "--cfg=ossl110",
        "--cfg=ossl110f",
        "--cfg=ossl110g",
        "--cfg=ossl111",
        "--cfg=ossl111b",
        "-l",
        "dylib=ssl",
        "-l",
        "dylib=crypto",
    ],
    version = "0.9.47",
    deps = [
        "@raze__libc__0_2_58//:libc",
    ],
)
