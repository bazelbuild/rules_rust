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


# Unsupported target "call_all" with type "test" omitted
# Unsupported target "service_fn" with type "test" omitted

rust_library(
    name = "tower_util",
    crate_type = "lib",
    deps = [
        "@raze__futures_core__0_3_5//:futures_core",
        "@raze__futures_util__0_3_5//:futures_util",
        "@raze__pin_project__0_4_23//:pin_project",
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
        "call-all",
        "default",
        "futures-util",
    ],
)

