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
  "notice", # "MIT"
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_library",
    "rust_binary",
    "rust_test",
)


# Unsupported target "current_thread" with type "test" omitted

rust_library(
    name = "tokio_current_thread",
    crate_root = "src/lib.rs",
    crate_type = "lib",
    srcs = glob(["**/*.rs"]),
    deps = [
        "@raze__futures__0_1_23//:futures",
        "@raze__tokio_executor__0_1_4//:tokio_executor",
    ],
    rustc_flags = [
        "--cap-lints allow",
    ],
    version = "0.1.1",
    crate_features = [
    ],
)

