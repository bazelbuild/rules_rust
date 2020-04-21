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


# Unsupported target "dir" with type "test" omitted
# Unsupported target "file" with type "test" omitted
# Unsupported target "link" with type "test" omitted
# Unsupported target "std-echo" with type "example" omitted

rust_library(
    name = "tokio_fs",
    crate_root = "src/lib.rs",
    crate_type = "lib",
    edition = "2015",
    srcs = glob(["**/*.rs"]),
    deps = [
        "@raze__futures__0_1_29//:futures",
        "@raze__tokio_io__0_1_13//:tokio_io",
        "@raze__tokio_threadpool__0_1_18//:tokio_threadpool",
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.1.7",
    crate_features = [
    ],
)

