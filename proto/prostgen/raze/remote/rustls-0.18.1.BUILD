"""
@generated
cargo-raze crate build file.

DO NOT EDIT! Replaced on runs of cargo-raze
"""
package(default_visibility = [
  # Public for visibility by "@raze__crate__version//" targets.
  #
  # Prefer access through "//proto/prostgen/raze", which limits external
  # visibility to explicit Cargo.toml dependencies.
  "//visibility:public",
])

licenses([
  "notice", # Apache-2.0 from expression "Apache-2.0 OR (ISC OR MIT)"
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_library",
    "rust_binary",
    "rust_test",
)


# Unsupported target "api" with type "test" omitted
# Unsupported target "bench" with type "example" omitted
# Unsupported target "benchmarks" with type "bench" omitted
# Unsupported target "benchmarks" with type "test" omitted
# Unsupported target "bogo_shim" with type "example" omitted
# Unsupported target "limitedclient" with type "example" omitted

rust_library(
    name = "rustls",
    crate_type = "lib",
    deps = [
        "@raze__base64__0_12_3//:base64",
        "@raze__log__0_4_11//:log",
        "@raze__ring__0_16_15//:ring",
        "@raze__sct__0_6_0//:sct",
        "@raze__webpki__0_21_3//:webpki",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2018",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.18.1",
    tags = ["cargo-raze"],
    crate_features = [
        "default",
        "log",
        "logging",
    ],
)

# Unsupported target "simple_0rtt_client" with type "example" omitted
# Unsupported target "simpleclient" with type "example" omitted
# Unsupported target "trytls_shim" with type "example" omitted
