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

rust_library(
    name = "argon2rs",
    srcs = glob(["**/*.rs"]),
    crate_features = [
    ],
    crate_root = "src/lib.rs",
    crate_type = "lib",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.2.5",
    deps = [
        "@raze__blake2_rfc__0_2_18//:blake2_rfc",
        "@raze__scoped_threadpool__0_1_9//:scoped_threadpool",
    ],
)

# Unsupported target "cli" with type "example" omitted
# Unsupported target "constant_eq" with type "bench" omitted
# Unsupported target "helloworld" with type "example" omitted
# Unsupported target "verifier" with type "example" omitted
# Unsupported target "versus_cargon" with type "bench" omitted
