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


# Unsupported target "clock" with type "test" omitted
# Unsupported target "deadline" with type "test" omitted
# Unsupported target "delay" with type "test" omitted
# Unsupported target "hammer" with type "test" omitted
# Unsupported target "interval" with type "test" omitted
# Unsupported target "queue" with type "test" omitted
# Unsupported target "throttle" with type "test" omitted
# Unsupported target "timeout" with type "test" omitted

rust_library(
    name = "tokio_timer",
    crate_root = "src/lib.rs",
    crate_type = "lib",
    edition = "2015",
    srcs = glob(["**/*.rs"]),
    deps = [
        "@raze__crossbeam_utils__0_7_2//:crossbeam_utils",
        "@raze__futures__0_1_29//:futures",
        "@raze__slab__0_4_2//:slab",
        "@raze__tokio_executor__0_1_10//:tokio_executor",
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.2.13",
    crate_features = [
    ],
)

