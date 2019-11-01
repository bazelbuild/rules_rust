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

rust_library(
    name = "futures_cpupool",
    srcs = glob(["**/*.rs"]),
    crate_features = [
        "default",
        "futures",
        "with-deprecated",
    ],
    crate_root = "src/lib.rs",
    crate_type = "lib",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.1.8",
    deps = [
        "@raze__futures__0_1_25//:futures",
        "@raze__num_cpus__1_8_0//:num_cpus",
    ],
)

# Unsupported target "smoke" with type "test" omitted
