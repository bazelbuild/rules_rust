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


# Unsupported target "compare_mozilla" with type "test" omitted
# Unsupported target "google" with type "example" omitted

rust_library(
    name = "rustls_native_certs",
    crate_type = "lib",
    deps = [
        "@raze__openssl_probe__0_1_2//:openssl_probe",
        "@raze__rustls__0_18_1//:rustls",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2018",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.4.0",
    tags = ["cargo-raze"],
    crate_features = [
    ],
)

# Unsupported target "smoketests" with type "test" omitted
