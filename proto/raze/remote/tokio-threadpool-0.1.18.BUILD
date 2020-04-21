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


# Unsupported target "basic" with type "bench" omitted
# Unsupported target "blocking" with type "bench" omitted
# Unsupported target "blocking" with type "test" omitted
# Unsupported target "depth" with type "bench" omitted
# Unsupported target "depth" with type "example" omitted
# Unsupported target "hammer" with type "test" omitted
# Unsupported target "hello" with type "example" omitted
# Unsupported target "threadpool" with type "test" omitted

rust_library(
    name = "tokio_threadpool",
    crate_root = "src/lib.rs",
    crate_type = "lib",
    edition = "2015",
    srcs = glob(["**/*.rs"]),
    deps = [
        "@raze__crossbeam_deque__0_7_3//:crossbeam_deque",
        "@raze__crossbeam_queue__0_2_1//:crossbeam_queue",
        "@raze__crossbeam_utils__0_7_2//:crossbeam_utils",
        "@raze__futures__0_1_29//:futures",
        "@raze__lazy_static__1_4_0//:lazy_static",
        "@raze__log__0_4_6//:log",
        "@raze__num_cpus__1_13_0//:num_cpus",
        "@raze__slab__0_4_2//:slab",
        "@raze__tokio_executor__0_1_10//:tokio_executor",
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.1.18",
    crate_features = [
    ],
)

