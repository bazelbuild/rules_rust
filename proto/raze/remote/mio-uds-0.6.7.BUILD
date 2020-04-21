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


# Unsupported target "echo" with type "test" omitted

rust_library(
    name = "mio_uds",
    crate_root = "src/lib.rs",
    crate_type = "lib",
    edition = "2015",
    srcs = glob(["**/*.rs"]),
    deps = [
        "@raze__iovec__0_1_4//:iovec",
        "@raze__libc__0_2_69//:libc",
        "@raze__mio__0_6_21//:mio",
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.6.7",
    crate_features = [
    ],
)

# Unsupported target "smoke" with type "test" omitted
