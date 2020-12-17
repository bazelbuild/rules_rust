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
  "notice", # MIT from expression "MIT"
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_library",
    "rust_binary",
    "rust_test",
)


# Unsupported target "ready_cache" with type "test" omitted

rust_library(
    name = "tower_ready_cache",
    crate_type = "lib",
    deps = [
        "@raze__futures_core__0_3_5//:futures_core",
        "@raze__futures_util__0_3_5//:futures_util",
        "@raze__indexmap__1_6_0//:indexmap",
        "@raze__log__0_4_11//:log",
        "@raze__tokio__0_2_22//:tokio",
        "@raze__tower_service__0_3_0//:tower_service",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2018",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.3.1",
    tags = ["cargo-raze"],
    crate_features = [
    ],
)

