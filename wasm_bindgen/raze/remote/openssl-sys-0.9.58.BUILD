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
    "notice",  # MIT from expression "MIT"
])

# Generated targets
# Unsupported target "build-script-main" with type "custom-build" omitted

# buildifier: leave-alone
rust_library(
    name = "openssl_sys",
    crate_type = "lib",
    deps = [
        "@rules_rust_wasm_bindgen__libc__0_2_79//:libc",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
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
    version = "0.9.58",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
    ],
)
