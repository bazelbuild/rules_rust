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
  "notice", # MIT from expression "MIT OR Apache-2.0"
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_library",
    "rust_binary",
    "rust_test",
)



rust_library(
    name = "futures_util",
    crate_type = "lib",
    deps = [
        "@raze__futures_core__0_3_5//:futures_core",
        "@raze__futures_task__0_3_5//:futures_task",
        "@raze__pin_project__0_4_23//:pin_project",
        "@raze__pin_utils__0_1_0//:pin_utils",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2018",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.3.5",
    tags = ["cargo-raze"],
    crate_features = [
        "alloc",
    ],
)

# Unsupported target "futures_unordered" with type "bench" omitted
