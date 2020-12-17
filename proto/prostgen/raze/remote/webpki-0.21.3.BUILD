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
  "restricted", # no license
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_library",
    "rust_binary",
    "rust_test",
)


# Unsupported target "dns_name_tests" with type "test" omitted
# Unsupported target "integration" with type "test" omitted

rust_library(
    name = "webpki",
    crate_type = "lib",
    deps = [
        "@raze__ring__0_16_15//:ring",
        "@raze__untrusted__0_7_1//:untrusted",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/webpki.rs",
    edition = "2018",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    data = glob(["**/src/data/*"]),
    version = "0.21.3",
    tags = ["cargo-raze"],
    crate_features = [
        "default",
        "std",
        "trust_anchor_util",
    ],
)

