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
    "notice",  # Apache-2.0 from expression "Apache-2.0"
])

# Generated targets
# Unsupported target "bench" with type "bench" omitted
# Unsupported target "hello-world" with type "example" omitted
# Unsupported target "input-tests" with type "test" omitted
# Unsupported target "network" with type "test" omitted
# Unsupported target "php-cgi" with type "example" omitted
# Unsupported target "readme-example" with type "example" omitted
# Unsupported target "serve-root" with type "example" omitted
# Unsupported target "simple-test" with type "test" omitted
# Unsupported target "ssl" with type "example" omitted

# buildifier: leave-alone
rust_library(
    name = "tiny_http",
    crate_type = "lib",
    deps = [
        "@rules_rust_wasm_bindgen__ascii__0_8_7//:ascii",
        "@rules_rust_wasm_bindgen__chrono__0_4_15//:chrono",
        "@rules_rust_wasm_bindgen__chunked_transfer__0_3_1//:chunked_transfer",
        "@rules_rust_wasm_bindgen__log__0_4_11//:log",
        "@rules_rust_wasm_bindgen__url__1_7_2//:url",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.6.2",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
        "default",
    ],
)
# Unsupported target "websockets" with type "example" omitted
