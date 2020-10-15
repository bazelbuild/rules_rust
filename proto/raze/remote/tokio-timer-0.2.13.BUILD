"""
@generated
cargo-raze crate build file.

DO NOT EDIT! Replaced on runs of cargo-raze
"""

# buildifier: disable=load
load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_binary",
    "rust_library",
    "rust_test",
)

# buildifier: disable=load
load("@bazel_skylib//lib:selects.bzl", "selects")

package(default_visibility = [
    # Public for visibility by "@raze__crate__version//" targets.
    #
    # Prefer access through "//proto/raze", which limits external
    # visibility to explicit Cargo.toml dependencies.
    "//visibility:public",
])

licenses([
    "notice",  # MIT from expression "MIT"
])

# Generated targets
# Unsupported target "clock" with type "test" omitted
# Unsupported target "deadline" with type "test" omitted
# Unsupported target "delay" with type "test" omitted
# Unsupported target "hammer" with type "test" omitted
# Unsupported target "interval" with type "test" omitted
# Unsupported target "queue" with type "test" omitted
# Unsupported target "throttle" with type "test" omitted
# Unsupported target "timeout" with type "test" omitted

# buildifier: leave-alone
rust_library(
    name = "tokio_timer",
    crate_type = "lib",
    deps = [
        "@rules_rust_proto__crossbeam_utils__0_7_2//:crossbeam_utils",
        "@rules_rust_proto__futures__0_1_29//:futures",
        "@rules_rust_proto__slab__0_4_2//:slab",
        "@rules_rust_proto__tokio_executor__0_1_10//:tokio_executor",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.2.13",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
    ],
)
