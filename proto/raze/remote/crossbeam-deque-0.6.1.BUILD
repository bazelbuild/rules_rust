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
  "notice", # "MIT,Apache-2.0"
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_library",
    "rust_binary",
    "rust_test",
)



rust_library(
    name = "crossbeam_deque",
    crate_root = "src/lib.rs",
    crate_type = "lib",
    srcs = glob(["**/*.rs"]),
    deps = [
        "@raze__crossbeam_epoch__0_5_2//:crossbeam_epoch",
        "@raze__crossbeam_utils__0_5_0//:crossbeam_utils",
    ],
    rustc_flags = [
        "--cap-lints allow",
    ],
    version = "0.6.1",
    crate_features = [
    ],
)

# Unsupported target "fifo" with type "test" omitted
# Unsupported target "lifo" with type "test" omitted
