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
  "notice", # Apache-2.0 from expression "Apache-2.0"
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_library",
    "rust_binary",
    "rust_test",
)



rust_library(
    name = "prost",
    crate_type = "lib",
    deps = [
        "@raze__bytes__0_5_6//:bytes",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2018",
    proc_macro_deps = [
        "@raze__prost_derive__0_6_1//:prost_derive",
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.6.1",
    tags = ["cargo-raze"],
    crate_features = [
        "default",
        "prost-derive",
    ],
)

# Unsupported target "varint" with type "bench" omitted
