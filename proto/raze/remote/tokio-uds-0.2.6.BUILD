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


# Unsupported target "datagram" with type "test" omitted
# Unsupported target "stream" with type "test" omitted

rust_library(
    name = "tokio_uds",
    crate_root = "src/lib.rs",
    crate_type = "lib",
    edition = "2015",
    srcs = glob(["**/*.rs"]),
    deps = [
        "@raze__bytes__0_4_12//:bytes",
        "@raze__futures__0_1_29//:futures",
        "@raze__iovec__0_1_4//:iovec",
        "@raze__libc__0_2_69//:libc",
        "@raze__log__0_4_6//:log",
        "@raze__mio__0_6_21//:mio",
        "@raze__mio_uds__0_6_7//:mio_uds",
        "@raze__tokio_codec__0_1_2//:tokio_codec",
        "@raze__tokio_io__0_1_13//:tokio_io",
        "@raze__tokio_reactor__0_1_12//:tokio_reactor",
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.2.6",
    crate_features = [
    ],
)

