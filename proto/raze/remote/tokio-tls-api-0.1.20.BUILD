"""
cargo-raze crate build file.

DO NOT EDIT! Replaced on runs of cargo-raze
"""

package(default_visibility = [
    # Public for visibility by "@raze__crate__version//" targets.
    #
    # Prefer access through "//proto/raze", which limits external
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

# Unsupported target "bad" with type "test" omitted
# Unsupported target "smoke" with type "test" omitted

rust_library(
    name = "tokio_tls_api",
    srcs = glob(["**/*.rs"]),
    crate_features = [
    ],
    crate_root = "src/lib.rs",
    crate_type = "lib",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.1.20",
    deps = [
        "@raze__futures__0_1_25//:futures",
        "@raze__tls_api__0_1_20//:tls_api",
        "@raze__tokio_core__0_1_17//:tokio_core",
        "@raze__tokio_io__0_1_10//:tokio_io",
    ],
)
